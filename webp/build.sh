#!/bin/bash

export PROJ="webp"
export VERSION="1.1.0"
export URL="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.1.0.tar.gz"
export DIRNAME="lib$PROJ-$VERSION"
export CONFIGOPTS="--disable-sse4.1"
export LICENSE="COPYING"

../build-std.sh
