#!/bin/bash

# TODO(pbos): Add installation of build dependencies, including git.
set -x

# Download libvpx if not available.
if [ ! -d libvpx ]; then
  git clone https://chromium.googlesource.com/webm/libvpx
fi

# Update libvpx
pushd libvpx
git pull

# Build libvpx
./configure --enable-experimental --enable-spatial-svc --enable-multi-res-encoding
make

popd

# Build tiny_ssim
clang tiny_ssim.c -o tiny_ssim -lm
