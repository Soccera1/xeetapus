#!/bin/sh
# Build GNU Texinfo from source
# Required for building documentation

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
TEXINFO_VERSION="7.1"

# Check if already available (system or prefix)
check="$(awk -v section="texinfo" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[texinfo] Already available"
    exit 0
fi

set -e

echo "[texinfo] Building from source..."

. "$SCRIPT_DIR/env.sh"

"$SCRIPT_DIR/stages/ncurses.sh"

cd "$CACHE_DIR"
wget -q --show-progress -O "texinfo.tar.gz" \
    "https://ftp.gnu.org/gnu/texinfo/texinfo-${TEXINFO_VERSION}.tar.gz"

tar xzf "texinfo.tar.gz"
cd "texinfo-${TEXINFO_VERSION}"

CPPFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" \
./configure --prefix="$PREFIX" --disable-shared \
    CFLAGS="-O2 -g"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

cd "$CACHE_DIR"
rm -rf "texinfo-${TEXINFO_VERSION}" "texinfo.tar.gz"

echo "[texinfo] Installed: $PREFIX/bin/texi2any"
