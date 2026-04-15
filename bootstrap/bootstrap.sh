#!/bin/sh
# Bootstrap script for xeetapus
# Requires: wget, sh, C99 compiler

PRETEND=0
for arg in "$@"; do
    case "$arg" in
        --pretend) PRETEND=1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_FILE="$SCRIPT_DIR/deps.ini"
CACHE_DIR="$SCRIPT_DIR/cache"
PREFIX="$CACHE_DIR/local"

mkdir -p "$CACHE_DIR" "$PREFIX/lib" "$PREFIX/include" "$PREFIX/bin"

# Get value for a key in a section
ini_get() {
    awk -v section="$1" -v key="^$2" '
        BEGIN { gsub(/\[|\]/, "", section); section = "[" section "]" }
        $0 == section { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && $0 ~ key { sub(/^[^=]+= */, ""); gsub(/^[ \t]+|[ \t]+$/, ""); print; exit }
    ' "$DEPS_FILE"
}

echo "=== Xeetapus Bootstrap ==="
echo ""

OUTPUT="$("$SCRIPT_DIR/check.sh" ${PRETEND:+--pretend} 2>&1)"
LAST_LINE="$(printf '%s' "$OUTPUT" | tail -1)"

echo "$OUTPUT"

if [ "${LAST_LINE#MISSING:}" = "$LAST_LINE" ]; then
    echo "Nothing to build."
    exit 0
fi

if [ "$PRETEND" = 1 ]; then
    echo "(Dry run - no packages were built)"
    exit 0
fi

MISSING="${LAST_LINE#MISSING:}"

echo ""
echo "Building:$MISSING"
echo ""

. "$SCRIPT_DIR/env.sh"

# Detect required compilers
C89_CC=""
C99_CC=""
C11_CC=""

for dep in $MISSING; do
    uses="$(ini_get "$dep" uses)"
    for tool in $uses; do
        case "$tool" in
            c89-compiler)
                if [ -z "$C89_CC" ]; then
                    for c in cc gcc clang; do
                        command -v $c >/dev/null 2>&1 || continue
                        printf 'int f(void) { return 0; }\nint main(void) { return f(); }' | \
                            $c -std=c89 -c -x c - -o /dev/null 2>/dev/null && C89_CC="$c" && break
                        printf 'int f(void) { return 0; }\nint main(void) { return f(); }' | \
                            $c -ansi -c -x c - -o /dev/null 2>/dev/null && C89_CC="$c" && break
                    done
                    [ -n "$C89_CC" ] && export C89_CC CC="$C89_CC"
                fi
                ;;
            c99-compiler)
                if [ -z "$C99_CC" ]; then
                    for c in cc gcc clang; do
                        command -v $c >/dev/null 2>&1 || continue
                        printf '// C99\ninline int f(void) { return 0; }\nint main(void) { long long x = 0; return f(); }' | \
                            $c -std=c99 -c -x c - -o /dev/null 2>/dev/null && C99_CC="$c" && break
                    done
                    [ -n "$C99_CC" ] && export C99_CC CC="$C99_CC"
                fi
                ;;
            c11-compiler)
                if [ -z "$C11_CC" ]; then
                    C11_TEST='
#include <stdalign.h>
_Noreturn void f(void) { }
int main(void) { _Static_assert(1,""); alignas(char) char c; return 0; }
'
                    for c in cc clang gcc; do
                        command -v $c >/dev/null 2>&1 || continue
                        printf '%s' "$C11_TEST" | $c -std=c11 -c -x c - -o /dev/null 2>/dev/null && C11_CC="$c" && break
                    done
                    [ -n "$C11_CC" ] && export C11_CC CC="$C11_CC"
                fi
                ;;
        esac
    done
done

for DEP in $MISSING; do
    case "$DEP" in
        build-dep:*)
            echo "ERROR: Missing build tool: ${DEP#build-dep:}"
            exit 1
            ;;
        *)
            stage_file="$(ini_get "$DEP" stage)"
            if [ -z "$stage_file" ]; then
                echo "ERROR: No stage defined for $DEP"
                exit 1
            fi
            echo "[$DEP] Running $stage_file..."
            "$SCRIPT_DIR/stages/$stage_file"
            . "$SCRIPT_DIR/env.sh"
            ;;
    esac
done

echo ""
echo "=== Bootstrap Complete ==="
