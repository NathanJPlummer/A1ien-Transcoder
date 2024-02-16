# Intel AV1 Video Transcoding Script

## Warning

This bash (Linux) script is designed for convenience and has undergone minimal testing. Use it at your own risk.

## About

This bash script provides a command-line interface for transcoding video files to the AV1 format using FFMPEG on **Intel Arc Hardware**. It supports both single-file and batch processing modes. The script is currently incompatible with NVIDIA or AMD cards, but future versions may include support.

This script relies on [Lisa Melton's Other Video Transcoding](https://github.com/lisamelton/other_video_transcoding) tool and requires it to be installed and accessible via your PATH.

This means it also shares the requirements of Lisa's tool:

- ffprobe
- ffmpeg
- mkvpropedit

## Current Features

Implemented.

- **Intel Arc AV1 Transcoding**
- **Single-File Mode**: Transcode a single video file to AV1.
- **Batch Mode**: Transcode all `.mkv` files in a specified directory to AV1.
- **Bitrate Adjustment**: Optionally adjust the bitrate and maxrate by a specified percentage.
- **Audio and Subtitle Copying**: Retains all audio tracks, subtitles, and metadata from the original file.
- **Deinterlace Detection** / BWDIF

BWDIF interlacing generally delivers superior results compared to YADIF, as discussed in detail [here](https://macilatthefront.blogspot.com/2021/05/which-deinterlacing-algorithm-is-best.html). However, it's worth noting that BWDIF is not the preferred choice for animated content.

## Upcoming Features

Not yet implemented.

- Use NVIDIA/AMD encoders
- Selected output folder

## Purpose

This script builds upon Lisa Melton's work by optimizing rate control values for AV1 encoding. It uses other-transcode in dry-run mode and makes the following adjustments:

- Switches from HEVC to AV1 for potentially higher quality and smaller file sizes.
- Copies all audio and subtitle tracks from the original file.
- Copies compatible metadata from the original file.
- Uses bwdif for deinterlacing if media is detected as interlaced (not recommended for interlaced animation).

## Prerequisites

- FFMPEG with AV1 encoding support (`av1_qsv`).
- The `other-transcode` script for initial processing.
- mkvpropedit, part of the [mkvtoolnix package](https://mkvtoolnix.download/).

## Usage

Give script permission to be executable. Then run script.

```bash
chmod +x ./av1_transcode_script
```

1. **Choose Mode**: Select either single-file mode (1) or batch mode (2) when prompted.
2. **Input File/Folder**: For single-file mode, provide the path to the video file. For batch mode, provide the path to the folder containing `.mkv` files.
3. **Ratecontrol Adjustment** (Optional, see below): Enter a percentage to adjust the bitrate and maxrate. Leave blank for default values.
4. **Transcoding**: The script will process the file(s) and display the final FFMPEG command before execution.

Output file will be located from the directory you ran the script.

## Ratecontrol adjustment

The script will give you an opportunity to adjust the rate control values by percentage. *These adjustments are relative to Lisa's values*. 

```bash
Enter the percentage to adjust ratecontrol  by. This can be negative. Hit enter for default values:
```



## Example Usage

```bash
./av1_transcode_script.sh
