#!/bin/bash

# TODO(pbos): Add installation of build dependencies, including git.
set -x

# Download libvpx if not available.
if [ ! -d libvpx ]; then
  git clone https://chromium.googlesource.com/webm/libvpx
fi

# Check out the correct libvpx version
pushd libvpx
git fetch
git checkout --detach 9205f54744f0a92ed32b775a80e9400d44f0f24b

# Build libvpx
./configure --enable-experimental --enable-spatial-svc --enable-multi-res-encoding
make
