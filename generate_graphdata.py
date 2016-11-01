#!/usr/bin/env python2

import os
import re
import subprocess
import sys

encoders = ["libvpx-vp8", "libvpx-vp9"]
layer_bitrates = [[1], [0.6, 1], [0.45, 0.65, 1]]

def exit_usage():
  sys.exit("Usage: " + sys.argv[0] + " source_file.WIDTH_HEIGHT.yuv:FPS...")

def generate_bitrates_kbps(target_bitrate_kbps, num_temporal_layers):
  bitrates_kbps = []
  for i in range(num_temporal_layers):
    layer_bitrate_kbps = int(layer_bitrates[num_temporal_layers-1][i] * target_bitrate_kbps)
    bitrates_kbps.append(layer_bitrate_kbps)
  return bitrates_kbps

def main():
  if len(sys.argv) == 1:
    exit_usage()

  clip_pattern = re.compile(r"^(.*\.(\d+)_(\d+).yuv):(\d+)$")

  if not os.path.exists('out'):
    os.makedirs('out')
  with open('out/graphdata.txt', 'w') as graphdata:
    for clip in sys.argv[1:]:
      clip_match = clip_pattern.match(clip)
      if not clip_match:
        exit_usage()
      input_file = clip_match.group(1)
      width = int(clip_match.group(2))
      height = int(clip_match.group(3))
      fps = int(clip_match.group(4))
      # TODO(pbos): Make sure clips exist.
      # TODO(pbos): Find interesting bitrates based on (width, height). Iterate
      #             through them.
      bitrates = 100,200,300,500,800,1600,3000
      for bitrate_kbps in bitrates:
        for num_spatial_layers in [1]:
          for num_temporal_layers in [1, 2, 3]:
            for encoder in encoders:
              encoder_config = "%s-%dsl%dtl" % (encoder, num_spatial_layers, num_temporal_layers)
              target_bitrates_kbps = generate_bitrates_kbps(bitrate_kbps, num_temporal_layers)
              bitrate_config = ":".join([str(i) for i in target_bitrates_kbps])
              output = subprocess.check_output(["bash", "generate_data.sh", encoder_config, bitrate_config, str(fps), input_file])
              graphdata.write(output)

if __name__ == '__main__':
  main()

