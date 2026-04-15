#!/bin/sh
# Build SQLite from source

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
SQLITE_VERSION="3450100"

# Check if already available (system or prefix)
check="$(awk -v section="sqlite" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[sqlite] Already available"
    exit 0
fi

set -e

echo "[sqlite] Building from source..."

cd "$CACHE_DIR"
wget -q --show-progress -O "sqlite.tar.gz" \
    "https://www.sqlite.org/2024/sqlite-autoconf-${SQLITE_VERSION}.tar.gz"

tar xzf "sqlite.tar.gz"
cd "sqlite-autoconf-${SQLITE_VERSION}"

./configure --prefix="$PREFIX" --disable-shared --enable-static \
    CFLAGS="-O2 -g -DNDEBUG -DSQLITE_THREADSAFE=1" \
    LDFLAGS="-L$PREFIX/lib"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

cd "$CACHE_DIR"
rm -rf "sqlite-autoconf-${SQLITE_VERSION}" "sqlite.tar.gz"

echo "[sqlite] Installed: $PREFIX/lib/libsqlite3.a"
