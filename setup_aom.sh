#!/bin/bash
# Copyright 2017 Google Inc. All rights reserved.
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

# Download aom if not available.
if [ ! -d aom ]; then
  git clone https://aomedia.googlesource.com/aom
fi

# Check out the pinned libvpx version.
pushd aom
git fetch
git checkout --detach 2615d6eaac3194b74ca61b95620f911047d7ad4b

# Build libvpx
./configure --enable-pic
make -j32
