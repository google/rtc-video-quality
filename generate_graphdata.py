#!/usr/bin/env python2
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

import argparse
import multiprocessing
import os
import re
import subprocess
import sys
import threading

layer_bitrates = [[1], [0.6, 1], [0.45, 0.65, 1]]

def clip_pair(clip):
  # Make sure files are correctly formatted + look readable before actually
  # running the script on them.
  clip_pattern = re.compile(r"^(.*[\._](\d+)_(\d+).yuv):(\d+)$")
  clip_match = clip_pattern.match(clip)
  if not clip_match:
    raise argparse.ArgumentTypeError("Argument '%s' doesn't match input format.\n" % clip)
  input_file = clip_match.group(1)
  if not os.path.isfile(input_file) or not os.access(input_file, os.R_OK):
    raise argparse.ArgumentTypeError("'%s' is either not a file or cannot be opened for reading.\n" % input_file)
  return {'input_file': clip_match.group(1), 'width': int(clip_match.group(2)), 'height': int(clip_match.group(3)), 'fps': int(clip_match.group(4))}

def encoder_pairs(string):
  pair_pattern = re.compile(r"^(\w+):(\w+)$")
  encoders = []
  for pair in string.split(','):
    pair_match = pair_pattern.match(pair)
    if not pair_match:
      raise argparse.ArgumentTypeError("Argument '%s' of '%s' doesn't match input format.\n" % (pair, string))
    encoders.append({'encoder': pair_match.group(1), 'codec': pair_match.group(2)})
  return encoders

parser = argparse.ArgumentParser(description='Generate graph data for video-quality comparison.')
parser.add_argument('clips', nargs='+', metavar='clip_WIDTH_HEIGHT.yuv:fps', type=clip_pair)
parser.add_argument('--workers', type=int, default=multiprocessing.cpu_count())
parser.add_argument('--encoders', required=True, metavar='encoder:codec,encoder:codec...', type=encoder_pairs)
parser.add_argument('--output', required=True, metavar='output.txt', type=argparse.FileType('w'))
parser.add_argument('--num_temporal_layers', type=int, default=1, choices=[1,2,3])
# TODO(pbos): Add support for multiple spatial layers.
parser.add_argument('--num_spatial_layers', type=int, default=1, choices=[1])

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

def generate_bitrates_kbps(target_bitrate_kbps, num_temporal_layers):
  bitrates_kbps = []
  for i in range(num_temporal_layers):
    layer_bitrate_kbps = int(layer_bitrates[num_temporal_layers - 1][i] * target_bitrate_kbps)
    bitrates_kbps.append(layer_bitrate_kbps)
  return bitrates_kbps

def generate_data_commands(args):
  commands = []
  for clip in args.clips:
    bitrates = find_bitrates(clip['width'], clip['height'])
    for bitrate_kbps in bitrates:
      for encoder_pair in args.encoders:
        encoder_config = "%s-%s-%dsl%dtl" % (encoder_pair['encoder'], encoder_pair['codec'], args.num_spatial_layers, args.num_temporal_layers)
        target_bitrates_kbps = generate_bitrates_kbps(bitrate_kbps, args.num_temporal_layers)
        bitrate_config = ":".join([str(i) for i in target_bitrates_kbps])
        commands.append(["bash", "generate_data.sh", encoder_config, bitrate_config, str(clip['fps']), clip['input_file']])
  return commands

def start_daemon(func):
  t = threading.Thread(target=func)
  t.daemon = True
  t.start()
  return t

def worker():
  global args
  global commands
  global current_job
  global total_jobs
  while True:
    with thread_lock:
      if not commands:
        return
      command = commands.pop()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (output, error) = process.communicate()
    with thread_lock:
      current_job += 1
      run_ok = process.returncode == 0
      print "[%d/%d] %s (%s)" % (current_job, total_jobs, " ".join(command[2:]), "OK" if run_ok else "ERROR")
      if not run_ok:
        print "\n"
        print error
      args.output.write(output)
      args.output.flush()


thread_lock = threading.Lock()

def main():
  if not os.path.exists('out'):
    os.makedirs('out')

  global args
  global commands
  global total_jobs
  global current_job

  args = parser.parse_args()
  commands = generate_data_commands(args)
  total_jobs = len(commands)
  current_job = 0

  print "[0/%d] Running jobs..." % total_jobs

  args.output.write('[')

  workers = [start_daemon(worker) for i in range(args.workers)]
  [t.join() for t in workers]

  args.output.write(']')

if __name__ == '__main__':
  main()

