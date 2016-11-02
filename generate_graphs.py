#!/usr/bin/env python2

import ast
import matplotlib.pyplot as plt

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
        lines[line_name] = metric_data

  graph_name = "%s-%s-%s:%s" % (graph_data[0]['input-file'], graph_data[0]['layer-pattern'], bitrate_config, target_metric)
  output_dict[graph_name] = lines

def main():
  with open('out/graphdata.txt') as f:
    graph_data = ast.literal_eval('[' + f.read() + ']')

  graph_dict = {}
  for input_files in split_data(graph_data, 'input-file'):
      for layer_pattern in split_data(input_files, 'layer-pattern'):
        normalized_bitrate_configs = {}
        for data in layer_pattern:
          config_split = [int(x) for x in data['bitrate-config-kbps'].split(':')]
          normalized_config = ":".join([str(int(x * 100.0 / config_split[-1])) for x in config_split])
          normalized_bitrate_configs[normalized_config] = data
        for normalized_config, data in normalized_bitrate_configs.iteritems():
          generate_graphs(graph_dict, layer_pattern, 'ssim', normalized_config)
          generate_graphs(graph_dict, layer_pattern, 'avg-psnr', normalized_config)
          generate_graphs(graph_dict, layer_pattern, 'glb-psnr', normalized_config)

  for graph_name, lines in graph_dict.iteritems():
    metric = graph_name.split(':')[-1]
    fig, ax = plt.subplots(1)
    ax.set_title(graph_name)
    ax.set_xlabel('Bitrate (kbps)')
    ax.set_ylabel(metric.upper())
    ax2 = ax.twinx()
    ax2.set_ylabel('Bitrate Utilization')
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
      ax.grid()
      ax2.plot(x,y2, 'x-', alpha=0.2)
    # Set bitrate limit axes to +/- 20%.
    ax2.set_ylim(bottom=0.80, top=1.20)
    plt.savefig("out/%s.png" % graph_name.replace(":", "-"))

if __name__ == '__main__':
  main()

