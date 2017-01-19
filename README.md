# Measuring Video Codec Performance

_This is not an official Google product._

![Example graph of SSIM-Y over multiple bitrates](example-ssim-y.png)
![Example graph of per-frame SSIM-Y inside a single clip](example-frame-ssim-y.png)

This project contains a couple of scripts that can be used to generate quality
metrics and graphs for different video codecs and video encoders.

Quality metrics can be generated for `.y4m` as well as `.yuv` raw I420 video
files. `.yuv` files require the special format `clip.WIDTH_HEIGHT.yuv:FPS` since
width, height and fps metadata are not available in this containerless format.

A set of industry-standard clips that can be used are available at
[Xiph.org Video Test Media](https://media.xiph.org/video/derf/), aka. "derf's
collection".


## Dependencies

To build pinned versions of dependencies, comparison tools and libvpx run:

    $ ./setup.sh

This requires `git` and build dependencies for libvpx that are not listed here.
See build instructions for libvpx for build dependencies.

To use `.y4m` files as input (instead of `.yuv`), `mediainfo` and `ffmpeg` are
both required (to extract metadata and convert to `.yuv`). They can either be
built and installed from source or likely by running (or similar depending on
distribution):

    $ sudo apt-get install ffmpeg mediainfo


## Encoders

After building dependencies with `./setup.sh` libvpx encoders are available.
Additional encoders have to be fetched and built by using their corresponding
setup scripts.

`libvpx-rt:vp8` and `libvpx-rt:vp9` use libvpx encoders with settings as close
as possible to settings used by Chromium's [WebRTC](https://code.webrtc.org)
implementation.

_TODO(pbos): Add reasonable non-realtime settings for `--good` and `--best`
settings as `libvpx-good` and `libvpx-best` encoders for comparison with
`aom-good`._

### libyami

To build pinned versions of libyami, VA-API and required utils run:

    $ ./setup_yami.sh

Using libyami encoders (`yami:vp8`, `yami:vp9`) requires VA-API hardware
encoding support that's at least available on newer Intel chipsets. Hardware
encoding support can be probed for with `vainfo`.

### aomedia

To build pinned versions of [aomedia](http://aomedia.org/) utils run:

    $ ./setup_aom.sh

This permits encoding and evaluating quality for the AV1 video codec by running
the encoder pair `aom-good:av1`. This runs a runs `aomenc` with `--good`
configured as a 2-pass non-realtime encoding. This is significantly slower than
realtime targets but provides better quality.

_There's currently no realtime target for AV1 encoding as the codec isn't
considered realtime ready at the point of writing. When it is, `aom-rt` should
be added and runs could then be reasonably compared to other realtime encoders
and codecs._


## Generating Data

To generate graph data (after building and installing dependencies), see:

    $ ./generate_graphdata.py --help

Example usage:

    $ ./generate_graphdata.py --output=out/libvpx.txt --encoders=libvpx:vp8,libvpx:vp9 clip1.320_240.yuv:30 clip2.320_180.yuv:30 clip3.y4m

This will generate `out/libvpx.txt` for example with an array of Python
dictionaries with metrics used later to build graphs. This part takes a long
time (may take hours or even days depending on clips, encoders and
configurations) as multiple clips are encoded using various settings. Make sure
to back up this file after running or risk running the whole thing all over
again.

To preserve encoded files, supply the `--encoded_file_dir` argument.

### Generating Graphs

To generate graphs from existing graph data run:

    $ generate_graphs.py --out_dir OUT_DIR graph_file.txt [graph_file.txt ...]

This will generate several `.png` files under `OUT_DIR` from graph files
generated using `generate_graphdata.py`, where each clip and temporal/spatial
configuration are grouped together to generate graphs comparing different
encoders and layer performances for separate `SSIM`, `AvgPSNR` and `GlbPSNR`
metrics. Multiple encoders and codecs are placed in the same graphs to enable a
comparison between them.

The script also generates graphs for encode time used. For speed tests it's
recommended to use a SSD or similar, along with a single worker instance to
minimize the impact that competing processes and disk/network drive performance
has on time spent encoding.

_The scripts make heavy use of temporary filespace. Every worker instance uses
disk space rougly equal to a few copies of the original raw video file that is
usually huge to begin with. To solve or mitigate issues where disk space runs
out during graph-data generation, either reduce the amount of workers used with
`--workers` or use another temporary directory (with more space available) by
changing the `TMPDIR` environment variable._


## Adding or Updating Encoder Implementations

Adding support for additional encoders are encouraged. This requires adding an
entry under `generate_graphdata.py` which handles the new encoder, optionally
including support for spatial/temporal configurations.

Any improvements upstream to encoder implementations have to be pulled in by
updating pinned revision hashes in corresponding setup/build scripts.
