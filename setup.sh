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
./configure --enable-pic --enable-experimental --enable-spatial-svc --enable-multi-res-encoding
make -j32
