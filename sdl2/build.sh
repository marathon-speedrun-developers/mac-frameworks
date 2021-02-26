#!/bin/bash

export PROJ="SDL2"
#This version is earliest with UB libraries for arm64
export VERSION="2.0.14"
export URL="https://www.libsdl.org/release/$PROJ-$VERSION.dmg"
export LICENSE="License.txt"

../copy-prebuilt.sh
