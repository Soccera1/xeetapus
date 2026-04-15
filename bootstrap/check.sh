#!/bin/sh
# Bootstrap dependency checker for xeetapus
# Reads dependencies from deps.ini
# Usage: check.sh [--pretend]

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

# Get value from top-level (before first section)
top_get() {
    awk -v key="^$1" '
        /^\[/ { exit }
        $0 ~ key { sub(/^[^=]+= */, ""); gsub(/^[ \t]+|[ \t]+$/, ""); print; exit }
    ' "$DEPS_FILE"
}

# Get all top-level keys
top_keys() {
    awk '
        /^\[/ { exit }
        /^[^#]/ && /=/ { sub(/=.*/, ""); gsub(/^[ \t]+|[ \t]+$/, ""); print }
    ' "$DEPS_FILE"
}

# Get all section names (package names)
ini_sections() {
    awk '/^\[/ { gsub(/\[|\]/, ""); print }' "$DEPS_FILE"
}

# Check if a C89 compiler is available (C99/C11 also satisfy C89)
check_c89_compiler() {
    for c in cc gcc clang; do
        command -v $c >/dev/null 2>&1 || continue
        # C89 test - basic C syntax
        printf 'int f(void) { return 0; }\nint main(void) { return f(); }' | \
            $c -std=c89 -c -x c - -o /dev/null 2>/dev/null && C89_CC="$c" && return 0
        printf 'int f(void) { return 0; }\nint main(void) { return f(); }' | \
            $c -ansi -c -x c - -o /dev/null 2>/dev/null && C89_CC="$c" && return 0
        # C99 also satisfies C89
        printf 'int f(void) { return 0; }\nint main(void) { return f(); }' | \
            $c -std=c99 -c -x c - -o /dev/null 2>/dev/null && C89_CC="$c" && return 0
        # C11 also satisfies C89
        printf 'int f(void) { return 0; }\nint main(void) { return f(); }' | \
            $c -std=c11 -c -x c - -o /dev/null 2>/dev/null && C89_CC="$c" && return 0
    done
    return 1
}

# Check if a C99 compiler is available (C11 also satisfies C99)
check_c99_compiler() {
    for c in cc gcc clang; do
        command -v $c >/dev/null 2>&1 || continue
        # C99 test - // comments, inline, long long
        printf '// C99 comment\ninline int f(void) { return 0; }\nint main(void) { long long x = 0; return f(); }' | \
            $c -std=c99 -c -x c - -o /dev/null 2>/dev/null && C99_CC="$c" && return 0
        # C11 also satisfies C99
        printf '// C99\ninline int f(void) { return 0; }\nint main(void) { long long x = 0; return f(); }' | \
            $c -std=c11 -c -x c - -o /dev/null 2>/dev/null && C99_CC="$c" && return 0
    done
    return 1
}

# Check if a C11 compiler is available
check_c11_compiler() {
    # C11 features to test: _Static_assert, _Noreturn, <stdalign.h>
    C11_TEST='
#include <stdalign.h>
_Noreturn void f(void) { }
int main(void) {
    _Static_assert(1, "C11 supported");
    alignas(char) char c;
    return 0;
}
'

    for c in cc clang gcc; do
        command -v $c >/dev/null 2>&1 || continue
        printf '%s' "$C11_TEST" | $c -std=c11 -c -x c - -o /dev/null 2>/dev/null && C11_CC="$c" && return 0
    done
    return 1
}

# Check a single package
check_pkg() {
    local pkg="$1"
    [ "$PRETEND" = 1 ] && return 1
    local check="$(ini_get "$pkg" check)"
    eval "$check" >/dev/null 2>&1
}

PASSED=""

# Find packages that nothing depends on (roots)
ALL_PKGS="$(ini_sections)"
ROOT_PKGS=""
for pkg in $ALL_PKGS; do
    NEEDED=0
    for other in $ALL_PKGS; do
        needs="$(ini_get "$other" needs)"
        case " $needs " in
            *" $pkg "*) NEEDED=1; break ;;
        esac
    done
    if [ "$NEEDED" = 0 ]; then
        ROOT_PKGS="$ROOT_PKGS $pkg"
    fi
done

# Check root packages first
MISSING_PKGS=""
for pkg in $ROOT_PKGS; do
    if check_pkg "$pkg"; then
        echo "OK: $pkg"
        PASSED="$PASSED $pkg"
    else
        echo "MISSING: $pkg"
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

# If all roots are satisfied, we're done
if [ -z "$MISSING_PKGS" ]; then
    echo ""
    echo "All dependencies satisfied."
    echo "" >&2
    exit 0
fi

echo ""
echo "---"

# Resolve dependencies for missing packages
RESOLVED=""
for pkg in $MISSING_PKGS; do
    collect_deps() {
        local dep="$1"
        case " $PASSED " in
            *" $dep "*) return ;;
        esac
        case " $RESOLVED " in
            *" $dep "*) return ;;
        esac
        RESOLVED="$RESOLVED $dep"

        for need in $(ini_get "$dep" needs); do
            collect_deps "$need"
        done
    }

    collect_deps "$pkg"
done

# Collect required build tools from packages
REQUIRED_TOOLS=""
for dep in $RESOLVED; do
    uses="$(ini_get "$dep" uses)"
    for tool in $uses; do
        case " $REQUIRED_TOOLS " in
            *" $tool "*) ;;
            *) REQUIRED_TOOLS="$REQUIRED_TOOLS $tool" ;;
        esac
    done
done

# Check required build tools
MISSING_TOOLS=""

for tool in $REQUIRED_TOOLS; do
    case "$tool" in
        c89-compiler)
            if [ "$PRETEND" = 1 ]; then
                # In pretend mode, c99 is available so c89 is satisfied
                echo "OK: c89-compiler (pretend: satisfied by c99)"
                PASSED="$PASSED c89-compiler"
            elif check_c89_compiler; then
                echo "OK: $C89_CC (C89 compiler)"
                PASSED="$PASSED c89-compiler"
            else
                echo "MISSING: c89-compiler"
                MISSING_TOOLS="$MISSING_TOOLS c89-compiler"
            fi
            ;;
        c99-compiler)
            if [ "$PRETEND" = 1 ]; then
                echo "OK: c99-compiler (pretend)"
                PASSED="$PASSED c99-compiler c89-compiler"
            elif check_c99_compiler; then
                echo "OK: $C99_CC (C99 compiler)"
                PASSED="$PASSED c99-compiler c89-compiler"
            elif check_c11_compiler; then
                echo "OK: $C11_CC (C11 compiler, satisfies C99)"
                PASSED="$PASSED c99-compiler c89-compiler c11-compiler"
            else
                echo "MISSING: c99-compiler"
                MISSING_TOOLS="$MISSING_TOOLS c99-compiler"
            fi
            ;;
        c11-compiler)
            case " $PASSED " in
                *" c11-compiler "*) continue ;;
            esac
            if [ "$PRETEND" = 1 ]; then
                case " $RESOLVED " in
                    *" gcc-c11 "*) echo "OK: c11-compiler (pretend: provided by gcc-c11)" ;;
                    *) echo "MISSING: c11-compiler (pretend)"
                       MISSING_TOOLS="$MISSING_TOOLS c11-compiler" ;;
                esac
            elif check_c11_compiler; then
                echo "OK: $C11_CC (C11 compiler)"
                PASSED="$PASSED c11-compiler"
            else
                echo "MISSING: c11-compiler"
                MISSING_TOOLS="$MISSING_TOOLS c11-compiler"
            fi
            ;;
        *)
            if [ "$PRETEND" = 1 ]; then
                case "$tool" in
                    make|wget) echo "OK: $tool (pretend)" ;;
                    *) echo "MISSING: $tool (pretend)"; MISSING_TOOLS="$MISSING_TOOLS $tool" ;;
                esac
            else
                check="$(top_get "$tool")"
                if eval "$check" >/dev/null 2>&1; then
                    echo "OK: $tool"
                    PASSED="$PASSED $tool"
                else
                    echo "MISSING: $tool"
                    MISSING_TOOLS="$MISSING_TOOLS $tool"
                fi
            fi
            ;;
    esac
done

# Filter to only packages with stages
FINAL=""
for dep in $RESOLVED; do
    stage="$(ini_get "$dep" stage)"
    case "$stage" in
        ?*) FINAL="$FINAL $dep" ;;
    esac
done

# Add missing tools
for tool in $MISSING_TOOLS; do
    FINAL="$FINAL build-dep:$tool"
done

if [ -z "$FINAL" ]; then
    echo ""
    echo "All dependencies satisfied."
    echo "" >&2
    exit 0
fi

if [ "$PRETEND" = 1 ]; then
    echo "" >&2
    echo "Would build:" >&2
    echo "" >&2
    for dep in $FINAL; do
        case "$dep" in
            build-dep:*) continue ;;
        esac
        stage="$(ini_get "$dep" stage)"
        echo "  - $dep -> $stage" >&2
    done
    for tool in $MISSING_TOOLS; do
        echo "  - MISSING: $tool" >&2
    done
fi

echo "" >&2
echo "MISSING:$FINAL" >&2
exit 1
