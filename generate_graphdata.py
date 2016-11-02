#!/usr/bin/env python2

import os
import re
import subprocess
import sys

encoders = ["libvpx-vp8", "libvpx-vp9"]
layer_bitrates = [[1], [0.6, 1], [0.45, 0.65, 1]]

def find_bitrates(width, height):
  # Do multiples of 100, because grouping based on bitrate splits in
  # generate_graphs.py doesn't round properly.

  # TODO(pbos): Propagate the bitrate split in the data instead of inferring it
  # from the config to avoid rounding errors.

  # Significantly lower than exact value, so 800p still counts as 720p for
  # instance.
  pixel_bound = width * height / 1.5
  if pixel_bound <= 320 * 240:
    return [100, 200, 400, 600, 800, 1200]
  if pixel_bound <= 640 * 480:
    return [200, 300, 500, 800, 1200, 2000]
  if pixel_bound <= 1280 * 720:
    return [400, 800, 1200, 1600, 2500, 5000]
  if pixel_bound <= 1920 * 1080:
    return [800, 1200, 2000, 3000, 5000, 10000]
  return [1200, 1800, 3000, 6000, 10000, 15000]

def exit_usage():
  sys.exit("Usage: " + sys.argv[0] + " source_file.WIDTH_HEIGHT.yuv:FPS...")

def generate_bitrates_kbps(target_bitrate_kbps, num_temporal_layers):
  bitrates_kbps = []
  for i in range(num_temporal_layers):
    layer_bitrate_kbps = int(layer_bitrates[num_temporal_layers - 1][i] * target_bitrate_kbps)
    bitrates_kbps.append(layer_bitrate_kbps)
  return bitrates_kbps

def main():
  if len(sys.argv) == 1:
    exit_usage()

  clip_pattern = re.compile(r"^(.*[\._](\d+)_(\d+).yuv):(\d+)$")

  if not os.path.exists('out'):
    os.makedirs('out')

  with open('out/graphdata.txt', 'w') as graphdata:
    # Make sure files are correctly formatted + look readable before actually
    # running the script on them.
    for clip in sys.argv[1:]:
      clip_match = clip_pattern.match(clip)
      if not clip_match:
        sys.stderr.write("Argument '%s' doesn't match input format.\n" % clip);
        exit_usage()
      input_file = clip_match.group(1)
      if not os.path.isfile(input_file) or not os.access(input_file, os.R_OK):
        sys.stderr.write("'%s' is either not a file or cannot be opened for reading.\n" % input_file)
        exit_usage()
    for clip in sys.argv[1:]:
      clip_match = clip_pattern.match(clip)
      input_file = clip_match.group(1)
      width = int(clip_match.group(2))
      height = int(clip_match.group(3))
      fps = int(clip_match.group(4))
      # TODO(pbos): Find interesting bitrates based on (width, height). Iterate
      #             through them.
      bitrates = find_bitrates(width, height)
      for bitrate_kbps in bitrates:
        for num_spatial_layers in [1]:
          for num_temporal_layers in [1, 2, 3]:
            for encoder in encoders:
              encoder_config = "%s-%dsl%dtl" % (encoder, num_spatial_layers, num_temporal_layers)
              target_bitrates_kbps = generate_bitrates_kbps(bitrate_kbps, num_temporal_layers)
              bitrate_config = ":".join([str(i) for i in target_bitrates_kbps])
              output = subprocess.check_output(["bash", "generate_data.sh", encoder_config, bitrate_config, str(fps), input_file])
              graphdata.write(output)
              graphdata.flush()

if __name__ == '__main__':
  main()

