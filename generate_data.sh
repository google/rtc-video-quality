#!/bin/bash
# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function help_and_exit() {
  >&2 echo "Usage: ./generate_data.sh ENCODER BITRATE_KBPS[:BITRATE_KBPS..] file.WIDTH_HEIGHT.yuv:FPS|file.y4m"
  exit 1
}

LIBVPX_THREADS=4
function libvpx() {
  # COMMON_PARAMS + CODEC_PARAMS are intended to be as close as possible to
  # realtime settings used in WebRTC.
  COMMON_PARAMS="--lag-in-frames=0 --error-resilient=1 --kf-min-dist=3000 --kf-max-dist=3000 --static-thresh=1 --end-usage=cbr --undershoot-pct=100 --overshoot-pct=15 --buf-sz=1000 --buf-initial-sz=500 --buf-optimal-sz=600 --max-intra-rate=900 --resize-allowed=0 --drop-frame=0 --passes=1 --rt --noise-sensitivity=0 --threads=$LIBVPX_THREADS"
  if [ "$CODEC" = "vp8" ]; then
    CODEC_PARAMS="--codec=vp8 --cpu-used=-6 --min-q=2 --max-q=56 --screen-content-mode=0"
  else
    # VP9
    CODEC_PARAMS="--codec=vp9 --cpu-used=7 --min-q=2 --max-q=52 --aq-mode=3"
  fi
  ENCODED_FILE_PREFIX="$OUT_DIR/out"
  ENCODED_FILE_SUFFIX=webm
  set -x
  >&2 libvpx/vpxenc $CODEC_PARAMS $COMMON_PARAMS --fps=$FPS/1 --target-bitrate=${BITRATES_KBPS[0]} --width=$WIDTH --height=$HEIGHT -o "${ENCODED_FILE_PREFIX}_0.webm" "$INPUT_FILE"
  { set +x; } 2>/dev/null
}

function play_mplayer() {
  mplayer -demuxer rawvideo -rawvideo w=$WIDTH:h=$HEIGHT:fps=$FPS:format=i420 "$INPUT_FILE"
  exit 0 # Do not continue with SSIM/PSNR comparison.
}

function libvpx_tl() {
  if [ "$CODEC" = "vp8" ]; then
    # TODO(pbos): Account for low resolutions (use CPU=4)
    CODEC_CPU=6
  else
    # VP9
    # TODO(pbos): Account for low resolutions (use CPU=5)
    CODEC_CPU=7
  fi
  if [ "$TEMPORAL_LAYERS" = "2" ]; then
    LAYER_STRATEGY=8
  elif [ "$TEMPORAL_LAYERS" = "3" ]; then
    LAYER_STRATEGY=10
  else
    >&2 echo Incorrect temporal layers.
    exit 1
  fi
  ENCODED_FILE_PREFIX="$OUT_DIR/out"
  ENCODED_FILE_SUFFIX=ivf
  set -x
  >&2 libvpx/examples/vpx_temporal_svc_encoder "$INPUT_FILE" "$ENCODED_FILE_PREFIX" $CODEC $WIDTH $HEIGHT 1 $FPS $CODEC_CPU 0 $LIBVPX_THREADS $LAYER_STRATEGY ${BITRATES_KBPS[@]}
  { set +x; } 2>/dev/null
}

function yami() {
  if [ "$CODEC" = "vp8" ]; then
    CODEC_PARAMS="-c VP8"
  else
    # VP9
    CODEC_PARAMS="-c VP9"
  fi
  ENCODED_FILE_PREFIX="$OUT_DIR/out"
  ENCODED_FILE_SUFFIX=ivf
  set -x
  >&2 yami/libyami/bin/yamiencode --rcmode CBR --ipperiod 1 --intraperiod 3000 $CODEC_PARAMS -i "$INPUT_FILE" -W $WIDTH -H $HEIGHT -f $FPS -o "${ENCODED_FILE_PREFIX}_0.ivf" -b ${BITRATES_KBPS[@]}
  { set +x; } 2>/dev/null
}

ENCODER="$1"
OUT_DIR=`mktemp -d`
# Extract temporal/spatial layer strategy if available, otherwise use 1/1.
if [[ "$ENCODER" =~ ^(.*)-([1-3])sl([1-3])tl$ ]]; then
  ENCODER=${BASH_REMATCH[1]}
  SPATIAL_LAYERS=${BASH_REMATCH[2]}
  TEMPORAL_LAYERS=${BASH_REMATCH[3]}
else
  SPATIAL_LAYERS=1
  TEMPORAL_LAYERS=1
fi

# Extract codec type if available.
if [[ "$ENCODER" =~ ^(.*)-(vp[8-9])$ ]]; then
  ENCODER=${BASH_REMATCH[1]}
  CODEC=${BASH_REMATCH[2]}
elif [[ "$ENCODER" =~ ^(.*)-(h264)$ ]]; then
  ENCODER=${BASH_REMATCH[1]}
  CODEC=${BASH_REMATCH[2]}
fi

if [ "$ENCODER" = "libvpx" ]; then
  # TODO(pbos): Add support for screencast settings.
  [ "$CODEC" = "vp8" ] || [ "$CODEC" = "vp9" ] || { >&2 echo Unsupported codec: "'$CODEC'"; help_and_exit; }
  if [ "$TEMPORAL_LAYERS" = "1" ]; then
    ENCODER_COMMAND=libvpx
  else
    ENCODER_COMMAND=libvpx_tl
  fi
  # TODO(pbos): Add support for multiple spatial layers.
  [ "$SPATIAL_LAYERS" = "1" ] || { >&2 echo "Command doesn't support >1 spatial layers yet. :("; help_and_exit; }
elif [ "$ENCODER" = "yami" ]; then
  [ "$CODEC" = "vp8" ] || [ "$CODEC" = "vp9" ] || { >&2 echo Unsupported codec: "'$CODEC'"; help_and_exit; }
  ENCODER_COMMAND=yami
  # TODO(pbos): Add support for multiple spatial/temporal layers.
  [ "$TEMPORAL_LAYERS" = "1" ] || { >&2 echo "Command doesn't support >1 temporal layers yet. :("; help_and_exit; }
  [ "$SPATIAL_LAYERS" = "1" ] || { >&2 echo "Command doesn't support >1 spatial layers yet. :("; help_and_exit; }
elif [ "$ENCODER" = "play" ]; then
  ENCODER_COMMAND=play_mplayer
  rmdir $OUT_DIR
else
  >&2 echo Unknown encoder: "'$ENCODER'"
  help_and_exit
fi

CONFIG_BITRATES_KBPS="$2"

if [ ! "$CONFIG_BITRATES_KBPS" ]; then
  help_and_exit
fi

# Split bitrates into array.
IFS=: read -r -a BITRATES_KBPS <<< "$CONFIG_BITRATES_KBPS"
[ "${#BITRATES_KBPS[@]}" = "$TEMPORAL_LAYERS" ] || { >&2 echo Bitrates do not match number of temporal layers.; help_and_exit; }

INPUT_FILE="$3"
if [[ "$INPUT_FILE" =~ \.y4m$ ]]; then
  ORIGINAL_FILE=$INPUT_FILE
  HEIGHT=$(mediainfo "--Inform=Video;%Height%" $ORIGINAL_FILE)
  WIDTH=$(mediainfo "--Inform=Video;%Width%" $ORIGINAL_FILE)
  FPS=$(mediainfo "--Inform=Video;%FrameRate%" $ORIGINAL_FILE)
  # Round FPS. For quality comparisons it's likely close enough to not be
  # misrepresentative. From a quality perspective there's no point to fully
  # respecting NTSC or other non-integer FPS formats here.
  FPS=`echo "($FPS + 0.5)/1" | bc`
  # Convert .y4m to .yuv, as .yuv is the file format that tiny_ssim uses for
  # comparisons.
  INPUT_FILE="$OUT_DIR/input-conv.yuv"
  ffmpeg -i "$ORIGINAL_FILE" "$INPUT_FILE" < /dev/null
else
[[ "$INPUT_FILE" =~ ([0-9]+)_([0-9]+).yuv:([0-9]+)$ ]] || { >&2 echo File needs to contain WIDTH_HEIGHT.yuv:FPS; help_and_exit; }
  WIDTH=${BASH_REMATCH[1]}
  HEIGHT=${BASH_REMATCH[2]}
  FPS=${BASH_REMATCH[3]}
  INPUT_FILE=${INPUT_FILE/%:[0-9]*/}
  ORIGINAL_FILE=$INPUT_FILE
fi

DECODED_FILE="out.${WIDTH}_${HEIGHT}.yuv"

START_TIME=$(date +%s.%N)
$ENCODER_COMMAND
END_TIME=$(date +%s.%N)

ORIGINAL_FILE_HASH=`sha1sum "$ORIGINAL_FILE" | awk '{print $1}'`
# Generate stats for each spatial/temporal layer. Highest first to generate
# accurate expected encode times based on the top layer.
for SPATIAL_LAYER in $(seq `expr $SPATIAL_LAYERS "-" 1` -1 0); do
for TEMPORAL_LAYER in $(seq `expr $TEMPORAL_LAYERS "-" 1` -1 0); do

# TODO(pbos): Handle spatial layers.
ENCODED_FILE="${ENCODED_FILE_PREFIX}_$TEMPORAL_LAYER.${ENCODED_FILE_SUFFIX}"
libvpx/vpxdec --i420 --codec=$CODEC -o "$OUT_DIR/$DECODED_FILE" "${ENCODED_FILE}" || { >&2 echo Failed to decode "${ENCODED_FILE}".; exit 1; }

# For temporal layers we need to skip input frames belonging to higher layers.
# When calculating bitrates we need to take into account that lower layers have
# lower frame rates.
TEMPORAL_DIVIDE=$(awk "BEGIN {print ( 2 ^ ( $TEMPORAL_LAYERS - 1 - $TEMPORAL_LAYER ))}")
TEMPORAL_SKIP=`expr $TEMPORAL_DIVIDE "-" 1`
LAYER_FPS=$(awk "BEGIN {printf \"%0f\n\", ( $FPS / $TEMPORAL_DIVIDE )}")

# Run tiny_ssim to generate SSIM/PSNR scores.
mapfile -t SSIM_RESULTS < <(libvpx/tools/tiny_ssim "$INPUT_FILE" "$OUT_DIR/$DECODED_FILE" ${WIDTH}x${HEIGHT} $TEMPORAL_SKIP)

for i in "${SSIM_RESULTS[@]}"; do
  fields=(${i//:/});
  if [ "${fields[0]}" = "AvgPSNR" ]; then
    AVG_PSNR=${fields[1]}
  elif [ "${fields[0]}" = "AvgPSNR-Y" ]; then
    AVG_PSNR_Y=${fields[1]}
  elif [ "${fields[0]}" = "AvgPSNR-U" ]; then
    AVG_PSNR_U=${fields[1]}
  elif [ "${fields[0]}" = "AvgPSNR-V" ]; then
    AVG_PSNR_V=${fields[1]}
  elif [ "${fields[0]}" = "GlbPSNR" ]; then
    GLB_PSNR=${fields[1]}
  elif [ "${fields[0]}" = "GlbPSNR-Y" ]; then
    GLB_PSNR_Y=${fields[1]}
  elif [ "${fields[0]}" = "GlbPSNR-U" ]; then
    GLB_PSNR_U=${fields[1]}
  elif [ "${fields[0]}" = "GlbPSNR-V" ]; then
    GLB_PSNR_V=${fields[1]}
  elif [ "${fields[0]}" = "VpxSSIM" ]; then
    VPX_SSIM=${fields[1]}
  elif [ "${fields[0]}" = "SSIM" ]; then
    SSIM=${fields[1]}
  elif [ "${fields[0]}" = "SSIM-Y" ]; then
    SSIM_Y=${fields[1]}
  elif [ "${fields[0]}" = "SSIM-U" ]; then
    SSIM_U=${fields[1]}
  elif [ "${fields[0]}" = "SSIM-V" ]; then
    SSIM_V=${fields[1]}
  elif [ "${fields[0]}" = "Nframes" ]; then
    NUM_FRAMES=${fields[1]}
  fi
done

# Calculate target/actual encode times only once from top temporal/spatial
# layers.
if [ $TEMPORAL_LAYER = $(expr $TEMPORAL_LAYERS "-" 1) ] && [ $SPATIAL_LAYER = $(expr $SPATIAL_LAYERS "-" 1) ]; then
  ACTUAL_ENCODE_TIME_MS=$(awk "BEGIN {printf \"%0f\n\", ( ($END_TIME - $START_TIME) * 1000 )}")
  TARGET_ENCODE_TIME_MS=$(awk "BEGIN {print ( $NUM_FRAMES / $FPS * 1000 )}")
  ENCODE_TIME_UTILIZATION=$(awk "BEGIN {printf \"%0f\n\", ( $ACTUAL_ENCODE_TIME_MS / $TARGET_ENCODE_TIME_MS )}")
fi

# Calculate target/actual bitrates.
BITRATE_USED_BPS=$(awk "BEGIN {printf \"%0.f\n\", (`wc -c < \"$ENCODED_FILE\"` * 8 * $LAYER_FPS / $NUM_FRAMES)}")
TARGET_BITRATE_BPS=`expr ${BITRATES_KBPS[${TEMPORAL_LAYER}]} "*" 1000`
BITRATE_UTILIZATION=$(awk "BEGIN {printf \"%0f\n\", ( $BITRATE_USED_BPS / $TARGET_BITRATE_BPS )}")

# Print results as a JSON object.
echo "{"
echo '  "input-file":' \"`basename $ORIGINAL_FILE`\",
echo '  "input-file-sha1sum":' \"$ORIGINAL_FILE_HASH\",
echo '  "width":' $WIDTH,
echo '  "height":' $HEIGHT,
echo '  "fps":' $FPS,
echo '  "layer-fps":' $LAYER_FPS,
echo '  "encoder":' \"$ENCODER\",
echo '  "codec":' \"$CODEC\",
echo '  "layer-pattern":' \"${SPATIAL_LAYERS}sl${TEMPORAL_LAYERS}tl\",
echo '  "bitrate-config-kbps":' \"$CONFIG_BITRATES_KBPS\",
echo '  "spatial-layer":' $SPATIAL_LAYER,
echo '  "temporal-layer":' $TEMPORAL_LAYER,
echo '  "avg-psnr":' $AVG_PSNR,
echo '  "avg-psnr-y":' $AVG_PSNR_Y,
echo '  "avg-psnr-u":' $AVG_PSNR_U,
echo '  "avg-psnr-v":' $AVG_PSNR_V,
echo '  "glb-psnr":' $GLB_PSNR,
echo '  "glb-psnr-y":' $GLB_PSNR_Y,
echo '  "glb-psnr-u":' $GLB_PSNR_U,
echo '  "glb-psnr-v":' $GLB_PSNR_V,
echo '  "vpx-ssim":' $VPX_SSIM,
echo '  "ssim":' $SSIM,
echo '  "ssim-y":' $SSIM_Y,
echo '  "ssim-u":' $SSIM_U,
echo '  "ssim-v":' $SSIM_V,
echo '  "target-bitrate-bps":' $TARGET_BITRATE_BPS,
echo '  "actual-bitrate-bps":' $BITRATE_USED_BPS,
echo '  "bitrate-utilization":' $BITRATE_UTILIZATION,
echo '  "target-encode-time-ms":' $TARGET_ENCODE_TIME_MS,
echo '  "actual-encode-time-ms":' $ACTUAL_ENCODE_TIME_MS,
echo '  "encode-time-utilization":' $ENCODE_TIME_UTILIZATION
echo "},"

done
done

# Remove temp directory.
rm -r $OUT_DIR
