# Real-Time Video Codec Performance

_This is not an official Google product._

This project contains a couple of `bash` and `python` scripts  that can be used
to generate quality metrics and graphs for realtime video codecs. Settings used
are aimed to be as close as possible to settings used by Chromium's
[WebRTC](https://code.webrtc.org) implementation.

Quality metrics can currently only be generated for `.yuv` files, any other raw
formats such as `.y4m` must currently be converted to `clip.WIDTH_HEIGHT.yuv`
before continuing. Width and height of the raw video is inferred from the
filename.

A set of clips that can be used for this purpose, but currently require
conversion before being used, are available at
[Xiph.org Video Test Media](https://media.xiph.org/video/derf/), aka. "derf's
collection".


## Building Dependencies

To build pinned versions of dependencies run:

    $ ./setup.sh

This requires installing git and build dependencies required to build libvpx out
of band.


## Generating Graphs

To generate graph data (after building dependencies), see:

    $ ./generate_graphdata.py --help

Example usage:

    $ ./generate_graphdata.py --output=out/libvpx.txt --encoders=libvpx:vp8,libvpx:vp9 clip1.320_240.yuv:30 clip2.320_180.yuv:30

This will generate `out/libvpx.txt` for example with an array of JSON-formatted
data with metrics used later to build graphs. This part takes a long time (may
take hours or even days depending on clips, encoders and configurations) as
multiple clips are encoded using various settings. Make sure to back up this
file after running or risk running the whole thing all over again.

To generate graphs from existing graph data run:

    $ generate_graphs.py --out_dir OUT_DIR graph_file.txt [graph_file.txt ...]

This will generate several `.png` files under `OUT_DIR` from graph files
generated using `generate_graphdata.py`, where each clip and temporal/spatial
configuration are grouped together to generate graphs comparing different
encoders and layer performances for separate `SSIM`, `AvgPSNR` and `GlbPSNR`
metrics. Multiple encoders and codecs are placed in the same graphs to enable a
comparison between them.


## Adding Encoder Implementations

This script currently only supports [libvpx](https://www.webmproject.org/code/)
implementations of VP8 and VP9. Adding support for additional encoders are
encouraged. This requires adding an entry under `generate_data.sh` which handles
the new encoder, optionally including support for spatial/temporal
configurations.
