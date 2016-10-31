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
git checkout --detach ae206924a621f42cac1a252f2695fac43c9b166a

# Build libvpx
./configure --enable-experimental --enable-spatial-svc --enable-multi-res-encoding
make
