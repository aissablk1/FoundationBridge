#!/usr/bin/env bash
# Construit le binaire universel FoundationBridge (arm64 + x86_64),
# executable nativement sur Apple Silicon et sous Rosetta / Intel.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "-> Build universel (arm64 + x86_64, release)..."
swift build -c release --arch arm64 --arch x86_64

BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/foundationbridge"
echo "-> Binaire : $BIN"
echo "-> Architectures :"
lipo -archs "$BIN"
echo "OK termine."
