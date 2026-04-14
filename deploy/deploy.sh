#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="/var/www/xeetapus"
SERVICE_NAME="xeetapus"
SERVICE_SCRIPT="/etc/init.d/${SERVICE_NAME}"
SOURCE_BINARY="${ROOT_DIR}/backend/zig-out/bin/xeetapus-backend"
TARGET_BINARY="${APP_DIR}/xeetapus-backend"
SOURCE_ENV="${ROOT_DIR}/backend/.env.example"
TARGET_ENV="${APP_DIR}/.env"
SOURCE_OPENRC="${ROOT_DIR}/deploy/openrc/${SERVICE_NAME}"
OWNER_USER="${SUDO_USER:-${DOAS_USER:-}}"

log() {
    printf '%s\n' "$*"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log "Run this deployment script as root."
        exit 1
    fi
}

restore_project_ownership() {
    if [ -z "${OWNER_USER}" ]; then
        return
    fi

    OWNER_GROUP="$(id -gn "$OWNER_USER")"
    chown "$OWNER_USER:$OWNER_GROUP" "$ROOT_DIR"
}

build_backend() {
    log "Building release backend..."

    if command -v just >/dev/null 2>&1; then
        if just --list 2>/dev/null | grep -Eq '(^|[[:space:]])build-backend-release([[:space:]]|$)'; then
            (cd "$ROOT_DIR" && just build-backend-release)
            return
        fi
    fi

    ZIG_CACHE_SUFFIX="$(id -u)"
    (cd "$ROOT_DIR/backend" && env ZIG_LOCAL_CACHE_DIR="/tmp/zig-cache-${ZIG_CACHE_SUFFIX}" ZIG_GLOBAL_CACHE_DIR="/tmp/zig-global-cache-${ZIG_CACHE_SUFFIX}" zig build -Doptimize=ReleaseFast)
}

build_docs() {
    log "Building unified HTML docs..."

    if command -v just >/dev/null 2>&1; then
        if just --list 2>/dev/null | grep -Eq '(^|[[:space:]])docs-html-single([[:space:]]|$)'; then
            (cd "$ROOT_DIR" && just docs-html-single)
            return
        fi
    fi

    (cd "$ROOT_DIR/docs/texi" && texi2any --html --no-split -o xeetapus.html xeetapus.texi)
    mkdir -p "$ROOT_DIR/backend/src/generated"
    cp "$ROOT_DIR/docs/texi/xeetapus.html" "$ROOT_DIR/backend/src/generated/docs.html"
}

stop_existing_instance() {
    if [ -x "$SERVICE_SCRIPT" ]; then
        log "Stopping existing service..."
        "$SERVICE_SCRIPT" stop || true
        return
    fi

    log "No existing init script found; skipping stop."
}

install_binary() {
    log "Installing backend binary..."
    mkdir -p "$APP_DIR"
    cp "$SOURCE_BINARY" "$TARGET_BINARY"
    chown nginx:nginx "$TARGET_BINARY"
    chmod 755 "$TARGET_BINARY"
}

install_placeholder_env() {
    if [ -f "$TARGET_ENV" ]; then
        return
    fi

    log "Installing placeholder .env..."
    cp "$SOURCE_ENV" "$TARGET_ENV"
    chmod 600 "$TARGET_ENV"
}

install_openrc_script() {
    log "Installing OpenRC script..."
    cp "$SOURCE_OPENRC" "$SERVICE_SCRIPT"
    chmod 755 "$SERVICE_SCRIPT"
}

start_instance() {
    log "Starting service..."

    if command -v rc-service >/dev/null 2>&1; then
        rc-service "$SERVICE_NAME" start
        return
    fi

    "$SERVICE_SCRIPT" start
}

main() {
    require_root
    trap restore_project_ownership EXIT
    build_docs
    build_backend
    stop_existing_instance
    install_binary
    install_placeholder_env
    install_openrc_script
    start_instance
    log "Deployment complete."
}

main "$@"
