#!/bin/sh
# Build ncurses from source
# Required by texinfo

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
NCURSES_VERSION="6.5"

# Check if already available (system or prefix)
check="$(awk -v section="ncurses" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[ncurses] Already available"
    exit 0
fi

set -e

echo "[ncurses] Building from source..."

cd "$CACHE_DIR"
wget -q --show-progress -O "ncurses-${NCURSES_VERSION}.tar.gz" \
    "https://invisible-mirror.net/archives/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"

tar xzf "ncurses-${NCURSES_VERSION}.tar.gz"
cd "ncurses-${NCURSES_VERSION}"

./configure --prefix="$PREFIX" --without-shared --enable-static \
    --without-cxx --without-cxx-binding --without-ada \
    --without-manpages --without-tests \
    CFLAGS="-O2 -g"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

cd "$CACHE_DIR"
rm -rf "ncurses-${NCURSES_VERSION}" "ncurses-${NCURSES_VERSION}.tar.gz"

echo "[ncurses] Installed: $PREFIX/lib/libncurses.a"
