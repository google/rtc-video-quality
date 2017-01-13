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
import ast
import matplotlib.pyplot as plt
import os

def writable_dir(directory):
  if not os.path.isdir(directory) or not os.access(directory, os.W_OK):
    raise argparse.ArgumentTypeError("'%s' is either not a directory or cannot be opened for writing.\n" % directory)
  return directory

parser = argparse.ArgumentParser(description='Generate graphs from data files.')
parser.add_argument('graph_files', nargs='+', metavar='graph_file.txt', type=argparse.FileType('r'))
parser.add_argument('--out_dir', required=True, type=writable_dir)

def split_data(graph_data, attribute):
  groups = {}
  for element in graph_data:
    value = element[attribute]
    if value not in groups:
      groups[value] = []
    groups[value].append(element)
  return groups.values()

def generate_graphs(output_dict, graph_data, target_metric, bitrate_config):
  lines = {}
  for encoder in split_data(graph_data, 'encoder'):
    for codec in split_data(encoder, 'codec'):
      for layer in split_data(codec, 'temporal-layer'):
        metric_data = []
        for data in layer:
          metric_data.append((int(data['target-bitrate-bps'])/1000, float(data[target_metric]), float(data['bitrate-utilization'])))
        line_name = '%s-%s-tl%d' % (layer[0]['encoder'], layer[0]['codec'], layer[0]['temporal-layer'])
        # Sort points on target bitrate.
        lines[line_name] = sorted(metric_data, key=lambda point: point[0])

  graph_name = "%s-%s-%s:%s" % (graph_data[0]['input-file'], graph_data[0]['layer-pattern'], bitrate_config, target_metric)
  output_dict[graph_name] = lines

def main():
  args = parser.parse_args()
  graph_data = []
  for f in args.graph_files:
    graph_data += ast.literal_eval(f.read())

  graph_dict = {}
  for input_files in split_data(graph_data, 'input-file'):
      for layer_pattern in split_data(input_files, 'layer-pattern'):
        normalized_bitrate_configs = {}
        for data in layer_pattern:
          config_split = data['bitrate-config-kbps']
          normalized_config = ":".join([str(int(x * 100.0 / config_split[-1])) for x in config_split])
          normalized_bitrate_configs[normalized_config] = data
        for normalized_config, data in normalized_bitrate_configs.iteritems():
          metrics = [
            'vpx-ssim',
            'ssim',
            'ssim-y',
            'ssim-u',
            'ssim-v',
            'avg-psnr',
            'avg-psnr-y',
            'avg-psnr-u',
            'avg-psnr-v',
            'glb-psnr',
            'glb-psnr-y',
            'glb-psnr-u',
            'glb-psnr-v',
            'encode-time-utilization',
          ]
          for metric in metrics:
            generate_graphs(graph_dict, layer_pattern, metric, normalized_config)

  for graph_name, lines in graph_dict.iteritems():
    metric = graph_name.split(':')[-1]
    fig, ax = plt.subplots()
    ax.set_title(graph_name)
    ax.set_xlabel('Layer Target Bitrate (kbps)')

    if metric == 'encode-time-utilization':
      plot_bitrate_utilization = False
      ax.set_ylabel('Encode time (fraction)')
      # Draw a reference line for realtime.
      ax.axhline(1.0, color='k', alpha=0.2, linestyle='--')
    else:
      plot_bitrate_utilization = True
      ax.set_ylabel(metric.upper())

    if plot_bitrate_utilization:
      ax2 = ax.twinx()
      ax2.set_ylabel('Bitrate Utilization (actual / target)')

    for title in sorted(lines.keys()):
      points = lines[title]
      x = []
      y = []
      y2 = []
      for bitrate_kbps, value, utilization in points:
          x.append(bitrate_kbps)
          y.append(value)
          y2.append(utilization)
      ax.plot(x,y,'o--', linewidth=1, label=title)
      ax.legend(loc='best', fancybox=True, framealpha=0.5)
      if plot_bitrate_utilization:
        ax2.plot(x,y2, 'x-', alpha=0.2)

    if metric == 'encode-time-utilization':
      # Make sure the horizontal reference line at 1.0 can be seen.
      (lower, upper) = ax.get_ylim()
      if upper < 1.10:
        ax.set_ylim(top=1.10)

    if plot_bitrate_utilization:
      # Set bitrate limit axes to +/- 20%.
      ax2.set_ylim(bottom=0.80, top=1.20)

    plt.savefig(os.path.join(args.out_dir, "%s.png" % graph_name.replace(":", "-")))
    plt.close()

if __name__ == '__main__':
  main()

