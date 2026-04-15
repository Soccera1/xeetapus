#!/bin/sh
# Build Zig from source using bootstrap.c (no LLVM required)
# Just needs a C11 compiler - builds the full compiler from scratch
# Uses wget to download source tarball from GitHub

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
ZIG_VERSION="0.14.0"

if command -v zig >/dev/null 2>&1; then
    echo "[zig] Available system-wide: $(zig version)"
    exit 0
fi

if [ -x "$PREFIX/bin/zig" ]; then
    echo "[zig] Found in prefix: $($PREFIX/bin/zig version)"
    exit 0
fi

. "$SCRIPT_DIR/env.sh"

cd "$CACHE_DIR"

if [ ! -f "zig-${ZIG_VERSION}.tar.gz" ]; then
    echo "[zig] Downloading source tarball..."
    wget -q --show-progress -O "zig-${ZIG_VERSION}.tar.gz" \
        "https://github.com/ziglang/zig/archive/refs/tags/${ZIG_VERSION}.tar.gz"
fi

if [ ! -d "zig-${ZIG_VERSION}" ]; then
    echo "[zig] Extracting..."
    tar xzf "zig-${ZIG_VERSION}.tar.gz"
fi

cd "zig-${ZIG_VERSION}"

echo "[zig] Building bootstrap compiler..."
cc -o bootstrap bootstrap.c

echo "[zig] Building Zig (this may take several minutes)..."
./bootstrap build -Doptimize=ReleaseFast

echo "[zig] Installing to $PREFIX..."
mkdir -p "$PREFIX/bin"
cp build/stage3/bin/zig "$PREFIX/bin/zig"
chmod +x "$PREFIX/bin/zig"

echo "[zig] Installed: $($PREFIX/bin/zig version)"
