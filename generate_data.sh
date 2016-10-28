#!/bin/bash

function help_and_exit() {
  >&2 echo "Usage: ./generate_data.sh ENCODER BITRATE_KBPS[:BITRATE_KBPS..] FPS file.WIDTH_HEIGHT.yuv"
  exit 1
}

function libvpx() {
  COMMON_PARAMS="--lag-in-frames=0 --error-resilient=1 --kf-min-dist=3000 --kf-max-dist=3000 --static-thresh=1 --end-usage=cbr --undershoot-pct=100 --overshoot-pct=15 --buf-sz=1000 --buf-initial-sz=500 --buf-optimal-sz=600 --max-intra-rate=900 --resize-allowed=0 --drop-frame=0 --passes=1 --rt --noise-sensitivity=0"
  if [ "$CODEC" = "vp8" ]; then
    CODEC_PARAMS="--codec=vp8 --cpu-used=-6 --min-q=2 --max-q=56 --screen-content-mode=0 --threads=4"
  else
    # VP9
    CODEC_PARAMS="--codec=vp9 --cpu-used=7 --min-q=2 --max-q=52 --aq-mode=3 --threads=8"
  fi
  ENCODED_FILE="$OUT_DIR/out.webm"
  set -x
  libvpx/vpxenc $CODEC_PARAMS $COMMON_PARAMS --fps=$FPS/1 --target-bitrate=${BITRATES_KBPS[0]} --width=$WIDTH --height=$HEIGHT -o "$ENCODED_FILE" "$FILE"
  { set +x; } 2>/dev/null
}

function play_mplayer() {
  mplayer -demuxer rawvideo -rawvideo w=$WIDTH:h=$HEIGHT:fps=$FPS:format=i420 "$FILE"
  exit 0 # Do not continue with SSIM/PSNR comparison.
}

function libvpx_tl() {
  THREADS=4
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
  ENCODED_FILE="$OUT_DIR/out"
  set -x
  libvpx/examples/vpx_temporal_svc_encoder "$FILE" "$ENCODED_FILE" $CODEC $WIDTH $HEIGHT 1 $FPS $CODEC_CPU 0 $THREADS $LAYER_STRATEGY ${BITRATES_KBPS[@]}
  { set +x; } 2>/dev/null
  # TODO(pbos): Support lower layers for SSIM/PSNR too.
  ENCODED_FILE=${ENCODED_FILE}_`expr $TEMPORAL_LAYERS "-" 1`.ivf
}

ENCODER="$1"
OUT_DIR=out/$ENCODER
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
  [ "$CODEC" = "vp8" ] || [ "$CODEC" = "vp9" ] || { >&2 echo Unsupported codec: "'$CODEC'"; help_and_exit; }
  if [ "$TEMPORAL_LAYERS" = "1" ]; then
    ENCODER_COMMAND=libvpx
  else
    ENCODER_COMMAND=libvpx_tl
  fi
  [ "$SPATIAL_LAYERS" = "1" ] || { >&2 echo "Command doesn't support >1 spatial layers yet. :("; help_and_exit; }
#TODO(pbos): Add support for more encoders here, libva/ffmpeg/etc.
elif [ "$ENCODER" = "play" ]; then
  ENCODER_COMMAND=play_mplayer
  OUT_DIR=""
else
  >&2 echo Unknown encoder: "'$ENCODER'"
  help_and_exit
fi

BITRATES_KBPS="$2"

if [ ! "$BITRATES_KBPS" ]; then
  help_and_exit
fi

# Split bitrates into array.
IFS=: read -r -a BITRATES_KBPS <<< "$BITRATES_KBPS"
[ "${#BITRATES_KBPS[@]}" = "$TEMPORAL_LAYERS" ] || { >&2 echo Bitrates do not match number of temporal layers.; help_and_exit; }

FPS="$3"

if [ ! "$FPS" ]; then
  help_and_exit
fi

FILE="$4"
[[ "$FILE" =~ ([0-9]+)_([0-9]+).yuv$ ]] || { >&2 echo File needs to contain WIDTH_HEIGHT.yuv; help_and_exit; }
WIDTH=${BASH_REMATCH[1]}
HEIGHT=${BASH_REMATCH[2]}
OUT_FILE="out.${WIDTH}_${HEIGHT}.yuv"

if [ "$OUT_DIR" ]; then
  if [ -d "$OUT_DIR" ]; then
    rm -r "$OUT_DIR"
  fi
  mkdir -p "$OUT_DIR"
fi

START_TIME=$(date +%s.%N)
$ENCODER_COMMAND
END_TIME=$(date +%s.%N)
ENCODE_SEC=$(bc <<< "($END_TIME - $START_TIME)")

libvpx/vpxdec --i420 --codec=$CODEC -o "$OUT_DIR/$OUT_FILE" "$ENCODED_FILE"

RESULTS=`libvpx/tools/tiny_ssim "$FILE" "$OUT_DIR/$OUT_FILE" ${WIDTH}x${HEIGHT}`
echo
echo "$FILE" "(${WIDTH}x${HEIGHT}@$FPS)" "->" "$ENCODED_FILE" "->" "$OUT_DIR/$OUT_FILE"
echo
echo Encoder: $ENCODER
echo Codec: $CODEC
echo SpatialLayers: $SPATIAL_LAYERS
echo TemporalLayers: $TEMPORAL_LAYERS
echo "$RESULTS"
[[ "$RESULTS" =~ Nframes:\ ([0-9]+) ]] || { >&2 echo HOLY WHAT BORK BORK; exit 1; }
FRAMES=${BASH_REMATCH[1]}
echo Target bitrate: `expr ${BITRATES_KBPS[-1]} "*" 1000`
BITRATE_USED=$(expr `wc -c < "$ENCODED_FILE"` "*" 8 "*" $FPS "/" $FRAMES)
echo Bitrate: $BITRATE_USED
echo BitrateUtilization: $(bc <<< "scale=2; $BITRATE_USED/(${BITRATES_KBPS[-1]} * 1000)")
echo EncodeMs: $(bc <<< "scale=0; $ENCODE_SEC * 1000")
echo EncodeTimeUsed: $(bc <<< "scale=2; $ENCODE_SEC / ($FRAMES / $FPS)")
