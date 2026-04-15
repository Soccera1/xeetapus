#!/usr/bin/env -S just --justfile
# Xeetapus Task Runner - https://github.com/casey/just

set dotenv-load
set positional-arguments

# Default recipe - show available commands
default:
    @just --list

# Clean build artifacts
clean:
    @echo "🧹 Cleaning build artifacts..."
    @cd backend && rm -rf zig-out .zig-cache
    @cd frontend && rm -rf node_modules dist
    @echo "✅ Clean complete!"

# Stop all Xeetapus processes and free ports
stop:
    @echo "🛑 Stopping Xeetapus..."
    @-pkill -x "xeetapus-backend" 2>/dev/null || true
    @-pkill -f "vite" 2>/dev/null || true
    @-lsof -ti:8080 | xargs -r kill 2>/dev/null || true
    @-lsof -ti:3000 | xargs -r kill 2>/dev/null || true
    @sleep 1
    @# Reset terminal settings in case they were borked
    @stty sane 2>/dev/null || true
    @echo "✅ All processes stopped"

# Build the backend (Zig)
build-backend:
    @echo "📦 Building Zig backend..."
    @mkdir -p /tmp/zig-cache-$(id -u) /tmp/zig-global-cache-$(id -u)
    @just docs-html-single
    @just docs-html-split-embed
    @cd backend && env ZIG_LOCAL_CACHE_DIR=/tmp/zig-cache-$(id -u) ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global-cache-$(id -u) zig build
    @echo "✅ Backend build complete!"

# Build the backend release binary
build-backend-release:
    @echo "📦 Building release Zig backend..."
    @mkdir -p /tmp/zig-cache-$(id -u) /tmp/zig-global-cache-$(id -u)
    @just docs-html-single
    @just docs-html-split-embed
    @cd backend && env ZIG_LOCAL_CACHE_DIR=/tmp/zig-cache-$(id -u) ZIG_GLOBAL_CACHE_DIR=/tmp/zig-global-cache-$(id -u) zig build -Doptimize=ReleaseFast
    @echo "✅ Release backend build complete!"

# Build the frontend (React)
build-frontend:
    @echo "📦 Building React frontend..."
    @cd frontend && bun install && bun run build
    @echo "✅ Frontend build complete!"

# Build everything
build: build-backend build-frontend
    @echo "✅ All builds complete!"

# Run the backend only
run-backend: build-backend
    @echo "🚀 Starting backend on port 8080..."
    @cd backend && env $(cat .env | grep -v '^#' | xargs) ./zig-out/bin/xeetapus-backend

# Run the frontend only (Vite dev server)
run-frontend:
    @echo "🚀 Starting React frontend on port 3000..."
    @cd frontend && bun run dev

# Run both backend and frontend (production mode)
run:
    @echo "🐙 Starting Xeetapus..."
    @just stop 2>/dev/null || true
    @just build
    @echo "🚀 Starting services..."
    @cd backend && env $(cat .env | grep -v '^#' | xargs) ./zig-out/bin/xeetapus-backend &
    @sleep 3
    @cd frontend && bunx serve dist -p 3000 &
    @echo ""
    @echo "✅ Xeetapus is running!"
    @echo "   Backend:  http://localhost:8080"
    @echo "   Frontend: http://localhost:3000"
    @echo ""
    @echo "Press Ctrl+C to stop"
    @wait

# Run in development mode (with hot reload)
dev:
    @echo "🐙 Starting Xeetapus in development mode..."
    @just stop 2>/dev/null || true
    @just build-backend
    @echo "🚀 Starting services..."
    @cd backend && env $(cat .env | grep -v '^#' | xargs) ./zig-out/bin/xeetapus-backend &
    @sleep 2
    @cd frontend && bun run dev &
    @echo ""
    @echo "✅ Xeetapus is running!"
    @echo "   Backend:  http://localhost:8080"
    @echo "   Frontend: http://localhost:3000"
    @echo ""
    @echo "Press Ctrl+C to stop"
    @wait

# Clean documentation build artifacts
docs-clean:
    @echo "🧹 Cleaning documentation artifacts..."
    @rm -rf docs/texi/html
    @rm -f docs/texi/xeetapus.info docs/texi/xeetapus.html docs/texi/xeetapus
    @rm -f backend/src/generated/docs.html
    @echo "✅ Documentation clean complete!"

# Build Info documentation
docs-info:
    @echo "📚 Building Info documentation..."
    @mkdir -p docs/texi
    @cd docs/texi && texi2any --info -o xeetapus.info xeetapus.texi
    @echo "✅ Info docs built: docs/texi/xeetapus.info"

# Build separate HTML files (one per node)
docs-html:
    @echo "📚 Building separate HTML documentation..."
    @mkdir -p docs/texi/html
    @cd docs/texi && texi2any --html -o html xeetapus.texi
    @echo "✅ Separate HTML docs built: docs/texi/html/"

# Build unified single-file HTML document
docs-html-single:
    @echo "📚 Building unified HTML documentation..."
    @mkdir -p docs/texi
    @cd docs/texi && texi2any --html --no-split -o xeetapus.html xeetapus.texi
    @mkdir -p backend/src/generated
    @cp docs/texi/xeetapus.html backend/src/generated/docs.html
    @echo "✅ Unified HTML doc built: docs/texi/xeetapus.html"

# Build split HTML docs and generate Zig embed file for backend
docs-html-split-embed: docs-html
    @echo "📚 Preparing split HTML docs for embedding..."
    @rm -rf backend/src/generated/split
    @mkdir -p backend/src/generated/split
    @cp docs/texi/html/*.html backend/src/generated/split/
    @echo '// Auto-generated - do not edit' > backend/src/generated/split_docs.zig
    @echo 'const std = @import("std");' >> backend/src/generated/split_docs.zig
    @echo '' >> backend/src/generated/split_docs.zig
    @echo 'pub const SplitDoc = struct {' >> backend/src/generated/split_docs.zig
    @echo '    name: []const u8,' >> backend/src/generated/split_docs.zig
    @echo '    content: []const u8,' >> backend/src/generated/split_docs.zig
    @echo '};' >> backend/src/generated/split_docs.zig
    @echo '' >> backend/src/generated/split_docs.zig
    @echo 'pub const docs = [_]SplitDoc{' >> backend/src/generated/split_docs.zig
    @for f in backend/src/generated/split/*.html; do \
        name=$(basename "$f"); \
        echo "    .{ .name = \"${name}\", .content = @embedFile(\"split/${name}\") }," >> backend/src/generated/split_docs.zig; \
    done
    @echo '};' >> backend/src/generated/split_docs.zig
    @echo '' >> backend/src/generated/split_docs.zig
    @echo 'pub fn find(name: []const u8) ?[]const u8 {' >> backend/src/generated/split_docs.zig
    @echo '    for (docs) |doc| {' >> backend/src/generated/split_docs.zig
    @echo '        if (std.mem.eql(u8, doc.name, name)) return doc.content;' >> backend/src/generated/split_docs.zig
    @echo '    }' >> backend/src/generated/split_docs.zig
    @echo '    return null;' >> backend/src/generated/split_docs.zig
    @echo '}' >> backend/src/generated/split_docs.zig
    @echo "✅ Split HTML docs embedded in backend"

# Build all documentation formats
docs: docs-info docs-html docs-html-single
    @echo "✅ All documentation built!"
    @echo "   Info:         docs/texi/xeetapus.info"
    @echo "   HTML split:   docs/texi/html/"
    @echo "   HTML unified: docs/texi/xeetapus.html"

# Deploy to the production host
deploy:
    @./deploy/deploy.sh
