#!/bin/bash
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

# This script is based on the libyami build instructions at:
# https://github.com/01org/libyami/wiki/Build

export YAMI_ROOT_DIR="`pwd`/yami"
export VAAPI_PREFIX="${YAMI_ROOT_DIR}/vaapi"
export LIBYAMI_PREFIX="${YAMI_ROOT_DIR}/libyami"
ADD_PKG_CONFIG_PATH="${VAAPI_PREFIX}/lib/pkgconfig/:${LIBYAMI_PREFIX}/lib/pkgconfig/"
ADD_LD_LIBRARY_PATH="${VAAPI_PREFIX}/lib/:${LIBYAMI_PREFIX}/lib/"
ADD_PATH="${VAAPI_PREFIX}/bin/:${LIBYAMI_PREFIX}/bin/"

PLATFORM_ARCH_64=`uname -a | grep x86_64`
if [ -n "$PKG_CONFIG_PATH" ]; then
    export PKG_CONFIG_PATH="${ADD_PKG_CONFIG_PATH}:$PKG_CONFIG_PATH"
elif [ -n "$PLATFORM_ARCH_64" ]; then
    export PKG_CONFIG_PATH="${ADD_PKG_CONFIG_PATH}:/usr/lib/pkgconfig/:/usr/lib/i386-linux-gnu/pkgconfig/"
else
    export PKG_CONFIG_PATH="${ADD_PKG_CONFIG_PATH}:/usr/lib/pkgconfig/:/usr/lib/x86_64-linux-gnu/pkgconfig/"
fi

export LD_LIBRARY_PATH="${ADD_LD_LIBRARY_PATH}:$LD_LIBRARY_PATH"

export PATH="${ADD_PATH}:$PATH"

set -e
set -x

mkdir -p "$YAMI_ROOT_DIR/build"

pushd "$YAMI_ROOT_DIR/build"

if [ ! -d libva ]; then
  git clone git://anongit.freedesktop.org/vaapi/libva
fi

if [ ! -d intel-driver ]; then
  git clone git://anongit.freedesktop.org/vaapi/intel-driver
fi

if [ ! -d libyami ]; then
  git clone -b apache https://github.com/01org/libyami.git
fi

if [ ! -d libyami-utils ]; then
  git clone https://github.com/01org/libyami-utils.git
fi

pushd libva
git fetch
git checkout --detach acbc209b9bed133e2feadb74a07d34f8c933dcc0
./autogen.sh "--prefix=$VAAPI_PREFIX" && make -j32 && make install
popd

pushd intel-driver
git fetch
git checkout --detach b86c3e9149ddd35113d39935a948e457eff74287
./autogen.sh "--prefix=$VAAPI_PREFIX" && make -j32 && make install
popd

pushd libyami
git fetch
git checkout --detach 2f813e2314f661d9f68e0f1e51140894dd7e313d
./autogen.sh --enable-vp8enc --enable-vp9enc --disable-x11 "--prefix=$LIBYAMI_PREFIX" && make -j32 && make install
popd

pushd libyami-utils
git fetch
git checkout --detach 076858a1dd3ca232742d87ad2afa85d0a384104c
./autogen.sh --disable-v4l2 --disable-tests-gles --disable-md5 --disable-x11 "--prefix=$LIBYAMI_PREFIX" && make -j32 && make install
popd
