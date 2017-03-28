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
import re

layer_regex_pattern = re.compile(r"^(\d)sl(\d)tl$")
def writable_dir(directory):
  if not os.path.isdir(directory) or not os.access(directory, os.W_OK):
    raise argparse.ArgumentTypeError("'%s' is either not a directory or cannot be opened for writing.\n" % directory)
  return directory

def formats(formats_list):
  formats = formats_list.split(',')
  for extension in formats:
    if extension not in ['png', 'svg']:
      raise argparse.ArgumentTypeError("'%s' is not a valid file format.\n" % extension)
  return formats


parser = argparse.ArgumentParser(description='Generate graphs from data files.')
parser.add_argument('graph_files', nargs='+', metavar='graph_file.txt', type=argparse.FileType('r'))
parser.add_argument('--out-dir', required=True, type=writable_dir)
parser.add_argument('--formats', type=formats, metavar='png,svg', help='comma-separated list of output formats', default=['png', 'svg'])

def split_data(graph_data, attribute):
  groups = {}
  for element in graph_data:
    value = element[attribute]
    if value not in groups:
      groups[value] = []
    groups[value].append(element)
  return groups.values()

def normalize_bitrate_config_string(config):
  return ":".join([str(int(x * 100.0 / config[-1])) for x in config])


def generate_graphs(output_dict, graph_data, target_metric, bitrate_config_string):
  lines = {}
  for encoder in split_data(graph_data, 'encoder'):
    for codec in split_data(encoder, 'codec'):
      for layer in split_data(codec, 'temporal-layer'):
        metric_data = []
        for data in layer:
          if target_metric not in data:
            return
          metric_data.append((data['target-bitrate-bps']/1000, data[target_metric], data['bitrate-utilization']))
        line_name = '%s:%s (tl%d)' % (layer[0]['encoder'], layer[0]['codec'], layer[0]['temporal-layer'])
        # Sort points on target bitrate.
        lines[line_name] = sorted(metric_data, key=lambda point: point[0])

  graph_name = "%s-%s-%s:%s" % (graph_data[0]['input-file'], graph_data[0]['layer-pattern'], bitrate_config_string, target_metric)
  output_dict[('', graph_name)] = lines

def main():
  args = parser.parse_args()
  graph_data = []
  for f in args.graph_files:
    graph_data += ast.literal_eval(f.read())

  graph_dict = {}
  for input_files in split_data(graph_data, 'input-file'):
    for layer_pattern in split_data(input_files, 'layer-pattern'):
      for data in layer_pattern:
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
          'vmaf'
        ]
        for metric in metrics:
          generate_graphs(graph_dict, layer_pattern, metric, normalize_bitrate_config_string(data['bitrate-config-kbps']))

  for point in graph_data:
    pattern_match = layer_regex_pattern.match(point['layer-pattern'])
    num_temporal_layers = int(pattern_match.group(2))
    temporal_divide = 2 ** (num_temporal_layers - 1 - point['temporal-layer'])
    frame_metrics = [
      'frame-ssim',
      'frame-ssim-y',
      'frame-ssim-u',
      'frame-ssim-v',
      'frame-psnr',
      'frame-psnr-y',
      'frame-psnr-u',
      'frame-psnr-v',
      'frame-qp',
      'frame-bytes',
      'frame-vmaf'
    ]
    for target_metric in frame_metrics:
      if target_metric not in point:
        continue

      split_on_codecs = target_metric == 'frame-qp'

      if split_on_codecs:
        graph_name = "%s-%s-%s-%dkbps-tl%d-%s:%s" % (point['input-file'], point['layer-pattern'], normalize_bitrate_config_string(point['bitrate-config-kbps']), point['bitrate-config-kbps'][-1], point['temporal-layer'], point['codec'], target_metric)
        line_name = '%s' % point['encoder']
      else:
        graph_name = "%s-%s-%s-%dkbps-tl%d:%s" % (point['input-file'], point['layer-pattern'], normalize_bitrate_config_string(point['bitrate-config-kbps']), point['bitrate-config-kbps'][-1], point['temporal-layer'], target_metric)
        line_name = '%s:%s' % (point['encoder'], point['codec'])
      graph_info = ('frame-data-%s/' % point['input-file'], graph_name)
      if not graph_info in graph_dict:
        graph_dict[graph_info] = {}
      line = []
      for idx, val in enumerate(point[target_metric]):
        frame_size = point['frame-bytes'][idx] if 'frame-bytes' in point else -1
        line.append((point['frame-offset'] + temporal_divide * idx + 1, val, frame_size))
      graph_dict[graph_info][line_name] = line

  current_graph = 1
  total_graphs = len(graph_dict)
  for (subdir, graph_name), lines in graph_dict.iteritems():
    print "[%d/%d] %s" % (current_graph, total_graphs, graph_name)
    current_graph += 1
    metric = graph_name.split(':')[-1]
    fig, ax = plt.subplots()
    ax.set_title(graph_name)
    frame_data = 'frame-' in metric
    ax2 = None
    ax2_bitrate_utilization = False
    linestyle = 'o--'
    ax2_linestyle = 'x-'

    if frame_data:
      ax.set_xlabel('Frame')
      linestyle = '-'
      if metric == 'frame-bytes':
        ax.set_ylabel('Frame Size (bytes / frame)')
      else:
        ax.set_ylabel(metric.replace('frame-', '').upper())
        ax2 = ax.twinx()
        ax2.set_ylabel('Frame Size (bytes / frame)')
        ax2_linestyle = '-'
    elif metric == 'encode-time-utilization':
      ax.set_xlabel('Layer Target Bitrate (kbps)')
      ax.set_ylabel('Encode Time (fraction)')
      # Draw a reference line for realtime.
      ax.axhline(1.0, color='k', alpha=0.2, linestyle='--')
    else:
      ax.set_xlabel('Layer Target Bitrate (kbps)')
      ax.set_ylabel(metric.upper())
      ax2 = ax.twinx()
      ax2.set_ylabel('Bitrate Utilization (actual / target)')
      ax2_bitrate_utilization = True

    for title in sorted(lines.keys()):
      points = lines[title]
      x = []
      y = []
      y2 = []
      for bitrate_kbps, value, utilization in points:
          x.append(bitrate_kbps)
          y.append(value)
          y2.append(utilization)
      ax.plot(x, y, linestyle, linewidth=1, label=title)
      if ax2:
        ax2.plot(x, y2, ax2_linestyle, alpha=0.2)
      ax.legend(loc='best', fancybox=True, framealpha=0.5)

    if metric == 'encode-time-utilization':
      # Make sure the horizontal reference line at 1.0 can be seen.
      (lower, upper) = ax.get_ylim()
      if upper < 1.10:
        ax.set_ylim(top=1.10)

    # TODO(pbos): Read 'input-total-frames' from input and set as graph xlim.
    if frame_data:
      ax.set_xlim(left=0)

    if ax2_bitrate_utilization:
      # Set bitrate limit axes to +/- 20%.
      ax2.set_ylim(bottom=0.80, top=1.20)

    for extension in args.formats:
      graph_dir =  os.path.join(args.out_dir, extension, subdir)
      if not os.path.exists(graph_dir):
        os.makedirs(graph_dir)
      plt.savefig(os.path.join(graph_dir, "%s.%s" % (graph_name.replace(":", "-"), extension)))
    plt.close()

if __name__ == '__main__':
  main()

