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

set -x

# Download vmaf if not available.
if [ ! -d vmaf ]; then
  git clone https://github.com/Netflix/vmaf.git
fi

# Check out the pinned vmaf version.
pushd vmaf
git fetch
git checkout --detach 45c57f7b67cebc301d85715669b9126063903ac2

# Build vmaf
make -j32
