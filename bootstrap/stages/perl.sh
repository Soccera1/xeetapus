#!/bin/sh
# Build Perl from source

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"
PERL_VERSION="5.40.0"

# Check if already available (system or prefix)
check="$(awk -v section="perl" -v key="^check" '
    BEGIN { section = "[" section "]" }
    $0 == section { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && $0 ~ key { sub(/^[^=]+= */, ""); print; exit }
' "$SCRIPT_DIR/deps.ini")"

if eval "$check" >/dev/null 2>&1; then
    echo "[perl] Already available"
    exit 0
fi

set -e

echo "[perl] Building from source..."

cd "$CACHE_DIR"
wget -q --show-progress -O "perl-${PERL_VERSION}.tar.gz" \
    "https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz"

tar xzf "perl-${PERL_VERSION}.tar.gz"
cd "perl-${PERL_VERSION}"

CFLAGS="-O2 -g" ./Configure -des -Dprefix="$PREFIX" \
    -Dprivlib="$PREFIX/lib/perl5" \
    -Darchlib="$PREFIX/lib/perl5" \
    -Dsitelib="$PREFIX/lib/perl5/site_perl" \
    -Dsitearch="$PREFIX/lib/perl5/site_perl" \
    make

make install

cd "$CACHE_DIR"
rm -rf "perl-${PERL_VERSION}" "perl-${PERL_VERSION}.tar.gz"

echo "[perl] Installed: $PREFIX/bin/perl"
