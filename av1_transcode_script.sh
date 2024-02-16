#!/bin/bash

# COLOR CODES
GREEN='\033[0;32m'   # Green: User choices
RED='\033[0;31m'     # Red: Current program process
MAGENTA='\033[0;35m' # Magenta: Highlighted program output
BLUE='\033[0;34m'    # Blue: Final FFMPEG Command
NC='\033[0m'         # No Color: Reset text color

# GLOBAL VARIABLES
input_file=""             # Video file for input in single file mode
folder=""                 # Folder input value in batch mode
ffmpeg_other_transcode="" # FFMPEG line processed by other-transcode
av1_command=""            # FFMPEG command line for execution
mode=""                   # User choice: single file (1) or batch mode (2)
percentage=0              # Bitrate and maxrate adjustment percentage. 0 keeps other-transcode's default values

# FUNCTIONS

# User selects single file or batch mode
get_mode() {
    while [[ "$mode" != "1" && "$mode" != "2" ]]; do
        echo -e "${GREEN}Which mode?${NC}"
        echo -e "${GREEN}1: Single-File mode${NC}"
        echo -e "${GREEN}2: Batch/Folder mode${NC}"
        echo ""
        # shellcheck disable=SC2162
        read -p "Enter your choice: " mode
    done

    if [ "$mode" == "1" ]; then
        echo -e "${NC}Single file mode"
    else
        echo -e "${NC}Batch/Folder mode"
    fi
    echo ""
}

# Function to find .mkv files in the $folder and save them to the global $mkv_array
get_mkv_list() {
    # Ensure $folder is not empty
    if [ -z "$folder" ]; then
        echo "Error: Folder path is not set."
        return 1 # Exit the function with an error status
    fi

    # Check if the specified folder exists
    if [ ! -d "$folder" ]; then
        echo "Error: The specified folder '$folder' does not exist."
        return 1 # Exit the function with an error status
    fi

    # Clear the mkv_array to ensure it's empty before starting
    mkv_array=()

    # Use find to populate the array with .mkv files, handling file names with spaces or unusual characters
    while IFS= read -r -d $'\0' file; do
        mkv_array+=("$file")
    done < <(find "$folder" -type f -name "*.mkv" -print0)

    # Check if any .mkv files were found
    if [ ${#mkv_array[@]} -eq 0 ]; then
        echo "No .mkv files found in '$folder'."
        return 1 # Exit the function with an error status
    else
        echo -e "${RED}Found ${#mkv_array[@]} .mkv files in '$folder'.${NC}\n"
    fi
}

# Provide instructions and process the file path input by the user
read_file_path() {
    echo "Please enter the location of a file:"
    IFS= read -r input_file_temp

    # Trim leading and trailing spaces and quotes
    input_file_temp=$(sed "s/^[[:space:]\']*//; s/[[:space:]\']*$//" <<<"$input_file_temp")

    # Resolve absolute path
    input_file=$(realpath "$input_file_temp" 2>/dev/null)

    # Validate the input is not empty
    if [[ -z "$input_file" ]]; then
        echo "No input provided or invalid file path."
        return 1 # Return failure if no input or invalid path
    fi

    # Check if file exists and is accessible
    if [ ! -f "$input_file" ]; then
        echo "File does not exist or is not accessible: $input_file"
        return 1 # Return failure if file doesn't exist or is inaccessible
    fi

    echo "Input file: $input_file"
}

# Function to prompt user for a folder path
# Function to prompt user for a folder path
get_folder() {
    while [ -z "$folder" ]; do
        # Prompt user to enter a folder path
        read -p "Please enter the path to a folder: " temp_folder

        # Trim quotes from path
        temp_folder="${temp_folder#\'}" # Remove leading single quote
        temp_folder="${temp_folder%\'}" # Remove trailing single quote
        temp_folder="${temp_folder#\"}" # Remove leading double quote
        temp_folder="${temp_folder%\"}" # Remove trailing double quote

        # Check if the input is empty
        if [ -z "$temp_folder" ]; then
            echo "Error: Empty input. Please provide a folder path."
            continue
        fi

        # Check if the input is a directory
        if [ ! -d "$temp_folder" ]; then
            echo "Error: '$temp_folder' is not a valid directory path."
            continue
        fi

        # Check if the user has permission to access the folder
        if [ ! -r "$temp_folder" ]; then
            echo "Error: Permission denied. You do not have read access to '$temp_folder'."
            continue
        fi

        # Assign the validated folder path to the global variable
        folder="$temp_folder"
        break # Ensure the loop exits once $folder is assigned
    done
}

# Runs the other-transcode script and extracts the FFMPEG values it provides
get_other_ffmpeg() {
    echo -e "\n${RED}Running other-transcode to get FFMPEG values. Might be a delay if cropping is enabled${NC}"

    other_transcode_cmd=(other-transcode -n --hevc --qsv --qsv-decoder --10-bit --main-audio 0 --crop auto "$input_file")

    # Run other-transcode and assign ffmpeg output to variable
    ffmpeg_other_transcode=$(other_transcode_output=$("${other_transcode_cmd[@]}" 2>&1) && grep 'ffmpeg ' <<<"$other_transcode_output")

    echo -e "${MAGENTA}$ffmpeg_other_transcode${NC}"

}

# Processes the FFMPEG command to add Intel AV1 as vcodec, and transfers over all audio, subtitle, and metadata options
get_av1_command() {
    echo -e "\n${RED}Parsing FFMPEG line to add AV1, all audio tracks, subtitles, metadata${NC}"
    av1_command="${ffmpeg_other_transcode//-map 0:0/}"
    av1_command="${av1_command//yadif/bwdif}"
    av1_command="${av1_command//-c:v hevc_qsv/-map_metadata 0 -c:a copy -c:s copy  -c:v av1_qsv}"
    av1_command="${av1_command//-load_plugin:v hevc_hw/}"
    av1_command=$(echo "$av1_command" | sed 's/-metadata:s:v title\\= -disposition:v default -an -sn -metadata:g title\\= -default_mode passthrough//')
    echo -e "${MAGENTA}AV1 command:\n$av1_command${NC}"
}

# Function to get the bitrate adjustment percentage from the user
get_bitrate_adjustment() {
    # Prompt the user to enter the percentage adjustment
    echo -en "${GREEN}Enter the percentage to adjust ratecontrol  by. This can be negative. Hit enter for default values: ${NC}"
    read -r percentage
}

update_bitrates() {
    # Exit the function early if percentage is not provided or is 0
    if [ -z "$percentage" ] || [ "$percentage" -eq 0 ]; then
        echo "No ratecontrol adjustment needed. Using default values."
        return
    fi

    # Retrieve current bitrates without the 'k' suffix for arithmetic operations
    bitrate=$(echo "$av1_command" | grep -oP '(?<=-b:v )\d+')
    maxrate=$(echo "$av1_command" | grep -oP '(?<=-maxrate:v )\d+')

    # Calculate new bitrates based on the percentage adjustment
    new_bitrate=$((bitrate + bitrate * percentage / 100))
    new_maxrate=$((maxrate + maxrate * percentage / 100))

    # Update the av1_command with the new bitrates, re-adding the 'k' suffix
    av1_command=$(echo "$av1_command" | sed "s/-b:v ${bitrate}k/-b:v ${new_bitrate}k/")
    av1_command=$(echo "$av1_command" | sed "s/-maxrate:v ${maxrate}k/-maxrate:v ${new_maxrate}k/")
}

# Main Script

get_mode

# If mode is 1 (Single-File mode)
if [ "$mode" == "1" ]; then
    # Get Input File
    read_file_path

    # Get the ffmpeg output from other_transcode
    get_other_ffmpeg

    # Process ffmpeg command to use intel av1, and to copy all audio, subtitles, and possible metadata
    get_av1_command

    # Optional processing of FFMPEG to update bit/maxrate by user entered percentage
    get_bitrate_adjustment
    update_bitrates

    # Display final command to user
    echo -e "\n\n${RED}Your final FFMPEG command:\n${BLUE}$av1_command\n\n${NC}"

    # Execute final ffmpeg command
    eval "$av1_command"
fi

# If mode is 1 (Single-File mode)
if [ "$mode" == "2" ]; then

    get_folder

    mkv_array=()
    get_mkv_list
    get_bitrate_adjustment

    # Loop through each file in mkv_array
    for file_path in "${mkv_array[@]}"; do

        input_file="$file_path"

        # Call get_other_ffmpeg function
        get_other_ffmpeg

        #Get AV1 FFMPEG line
        get_av1_command

        # Call update_bitrates function
        update_bitrates

        # Display final command to user
        echo -e "\n\n${BLUE}Your final FFMPEG command:\n$av1_command\n\n${NC}"

        # Assuming av1_command is constructed within get_other_ffmpeg or update_bitrates
        # and is ready to be evaluated as an ffmpeg command.
        eval "$av1_command"
    done

fi

exit
