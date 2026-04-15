#!/bin/sh
# Set up environment for bootstrapped dependencies

CACHE_DIR="${SCRIPT_DIR:-$(cd "$(dirname "$0")" && pwd)}/cache"
PREFIX="$CACHE_DIR/local"

export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

# Use detected compilers
[ -n "$C89_CC" ] && export CC="$C89_CC"
[ -n "$C99_CC" ] && export CC="$C99_CC"
[ -n "$C11_CC" ] && export CC="$C11_CC"
