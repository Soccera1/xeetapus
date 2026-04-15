#!/bin/sh
# Build GMP (GNU Multiple Precision Library) from source
# Required by GCC

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
GMP_VERSION="6.3.0"

# Check if already available (system or prefix)
check="$(awk -v section="gmp" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[gmp] Already available"
    exit 0
fi

set -e

echo "[gmp] Building from source..."

cd "$CACHE_DIR"
wget -q --show-progress -O "gmp-${GMP_VERSION}.tar.xz" \
    "https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz"

tar xf "gmp-${GMP_VERSION}.tar.xz"
cd "gmp-${GMP_VERSION}"

./configure --prefix="$PREFIX" --enable-cxx --disable-shared \
    CFLAGS="-O2 -g"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

cd "$CACHE_DIR"
rm -rf "gmp-${GMP_VERSION}" "gmp-${GMP_VERSION}.tar.xz"

echo "[gmp] Installed: $PREFIX/lib/libgmp.a"
