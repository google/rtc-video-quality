# Real-Time Video Codec Performance

This project contains a couple of `bash`/`python` scripts  that can be used to
generate quality metrics and graphs for realtime video codecs. Settings used are
aimed to be as close as possible to settings used by Chromium's
[WebRTC](https://code.webrtc.org) implementation.

Quality metrics can currently only be generated for `.yuv` files, any other raw
formats such as `.y4m` must currently be converted to `clip.WIDTH_HEIGHT.yuv`
before continuing. Width and height of the raw video is inferred from the
filename.

_This is not an official Google product._

## Building Dependencies

To build pinned versions of dependencies run:

    $ ./setup.sh

This requires installing git and build dependencies required to build libvpx out
of band.

## Generating Graphs

To generate graph data (after building dependencies), run:

    $ ./generate_graphdata.py clip.WIDTH_HEIGHT.yuv:FPS..

This will generate `out/graphdata.txt` which contains an array of JSON-formatted
data with metrics used to build graphs. This part takes a long time (may take
hours or even days depending on clips) as multiple clips are encoded using
various settings. Make sure to copy this file somewhere else after running or
risk running the whole thing again.

To generate graphs from existing graph data run:

    $ ./generate_graphs.py

This will generate several `.png` files under `out/`, where each clip and
temporal/spatial configuration are grouped together to generate graphs comparing
different encoders and layer performances for separate `SSIM`, `AvgPSNR` and
`GlbPSNR` metrics.

## Adding Encoder Implementations

This script currently only supports [libvpx](https://www.webmproject.org/code/)
implementations of VP8 and VP9. Adding support for additional encoders are
encouraged. This requires adding an entry under `generate_data.sh` which handles
the new encoder, including support for spatial/temporal configurations. To have
it run as part of data generation, add it to `generate_graphdata.py` as well.
