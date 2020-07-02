#!/bin/bash
set -e
set -x

# Download rav1e if not available
if [ ! -d rav1e ]; then
 git clone http://github.com/xiph/rav1e
fi

# Check out to rav1e
pushd rav1e
git fetch

# Build rav1e
cargo build --release

