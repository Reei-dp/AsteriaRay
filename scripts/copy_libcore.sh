#!/bin/bash
# Copy libcore.aar from NekoBoxForAndroid to AsteriaRay and remove old libbox.
# Run from AsteriaRay root. Build libcore first in NekoBoxForAndroid: ./run lib core

set -e
NEKO="../NekoBoxForAndroid"
if [ -n "$1" ]; then
  NEKO="$1"
fi

if [ ! -f "$NEKO/app/libs/libcore.aar" ]; then
  echo "Error: $NEKO/app/libs/libcore.aar not found. Build it first: cd NekoBoxForAndroid && ./run lib core"
  exit 1
fi

cp -f "$NEKO/app/libs/libcore.aar" android/app/libs/
rm -f android/app/libs/libbox.aar
echo "Done: libcore.aar installed, libbox.aar removed."
