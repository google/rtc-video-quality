#!/bin/bash

set -e
set -x

if [ ! -d dav1d ]; then
    git clone https://code.videolan.org/videolan/dav1d
fi

# Check out to dav1d
pushd dav1d
git fetch

# Build dav1d
mkdir build
cd build
meson .. --default-library=static
ninja