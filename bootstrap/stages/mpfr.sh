#!/bin/sh
# Build MPFR (Multiple Precision Floating-Point Rounding) from source
# Required by GCC

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
MPFR_VERSION="4.2.1"

# Check if already available (system or prefix)
check="$(awk -v section="mpfr" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[mpfr] Already available"
    exit 0
fi

set -e

echo "[mpfr] Building from source..."

cd "$CACHE_DIR"
wget -q --show-progress -O "mpfr-${MPFR_VERSION}.tar.xz" \
    "https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz"

tar xf "mpfr-${MPFR_VERSION}.tar.xz"
cd "mpfr-${MPFR_VERSION}"

./configure --prefix="$PREFIX" --disable-shared \
    CFLAGS="-O2 -g" LDFLAGS="-L$PREFIX/lib" \
    GMP_CFLAGS="-I$PREFIX/include" GMP_LIBS="-L$PREFIX/lib -lgmp"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

cd "$CACHE_DIR"
rm -rf "mpfr-${MPFR_VERSION}" "mpfr-${MPFR_VERSION}.tar.xz"

echo "[mpfr] Installed: $PREFIX/lib/libmpfr.a"
