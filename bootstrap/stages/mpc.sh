#!/bin/sh
# Build MPC (Multiple Precision Complex) from source
# Required by GCC

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
MPC_VERSION="1.3.1"

# Check if already available (system or prefix)
check="$(awk -v section="mpc" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[mpc] Already available"
    exit 0
fi

set -e

echo "[mpc] Building from source..."

cd "$CACHE_DIR"
wget -q --show-progress -O "mpc-${MPC_VERSION}.tar.gz" \
    "https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz"

tar xzf "mpc-${MPC_VERSION}.tar.gz"
cd "mpc-${MPC_VERSION}"

./configure --prefix="$PREFIX" --disable-shared \
    CFLAGS="-O2 -g" LDFLAGS="-L$PREFIX/lib" \
    MPC_CFLAGS="-I$PREFIX/include" MPC_LIBS="-L$PREFIX/lib -lmpfr -lgmp"

make -j"$(nproc 2>/dev/null || echo 4)"
make install

cd "$CACHE_DIR"
rm -rf "mpc-${MPC_VERSION}" "mpc-${MPC_VERSION}.tar.gz"

echo "[mpc] Installed: $PREFIX/lib/libmpc.a"
