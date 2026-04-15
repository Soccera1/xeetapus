#!/bin/sh
# Build a minimal GCC with only C language support from existing C99 compiler
# This GCC will be C11 capable and used to build Zig stage0

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
GCC_VERSION="14.2.0"

find_c99_compiler() {
    for c in gcc clang cc tcc "${CC:-}"; do
        if [ -n "$c" ] && command -v $c >/dev/null 2>&1; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

C99_CC="$(find_c99_compiler)"

if [ -n "$C99_CC" ]; then
    echo "[gcc-c11] Found C99 compiler: $C99_CC"
fi

if [ -x "$PREFIX/bin/gcc" ]; then
    echo "[gcc-c11] Found in prefix: $($PREFIX/bin/gcc --version | head -1)"
    exit 0
fi

if [ -z "$C99_CC" ]; then
    echo "ERROR: No C99 compiler found (tried: gcc, clang, cc, tcc)"
    exit 1
fi

echo "[gcc-c11] Building minimal GCC $GCC_VERSION (C-only) from C99 compiler $C99_CC..."

. "$SCRIPT_DIR/env.sh"

"$SCRIPT_DIR/stages/gmp.sh"
"$SCRIPT_DIR/stages/mpfr.sh"
"$SCRIPT_DIR/stages/mpc.sh"

cd "$CACHE_DIR"

if [ ! -f "gcc-${GCC_VERSION}.tar.xz" ]; then
    echo "[gcc-c11] Downloading GCC $GCC_VERSION..."
    wget -q --show-progress -O "gcc-${GCC_VERSION}.tar.xz" \
        "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
fi

if [ ! -d "gcc-${GCC_VERSION}" ]; then
    echo "[gcc-c11] Extracting..."
    tar xf "gcc-${GCC_VERSION}.tar.xz"
fi

cd "gcc-${GCC_VERSION}"

for prereq in gmp mpfr mpc; do
    ln -sf "$PREFIX" "$prereq" 2>/dev/null || true
done

BUILD_DIR="$CACHE_DIR/gcc-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "[gcc-c11] Configuring (C-only, minimal)..."
LDFLAGS="-L$PREFIX/lib" \
CFLAGS="-O2 -g -I$PREFIX/include" \
"$CACHE_DIR/gcc-${GCC_VERSION}/configure" \
    --prefix="$PREFIX" \
    --enable-languages=c \
    --disable-multilib \
    --disable-shared \
    --disable-bootstrap \
    --without-headers \
    --with-newlib \
    --enable-threads=posix \
    --target=x86_64-linux-gnu \
    --with-gmp="$PREFIX" \
    --with-mpfr="$PREFIX" \
    --with-mpc="$PREFIX" \
    CC="$C99_CC"

echo "[gcc-c11] Building (this may take a while)..."
make -j"$(nproc 2>/dev/null || echo 4)" all-gcc

echo "[gcc-c11] Installing..."
make install-gcc

echo "[gcc-c11] Installed: $($PREFIX/bin/gcc --version | head -1)"
