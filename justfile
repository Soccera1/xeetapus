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
    @cd backend && rm -rf zig-out zig-cache
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
    @cd backend && zig build
    @echo "✅ Backend build complete!"

# Build the frontend (React)
build-frontend:
    @echo "📦 Building React frontend..."
    @cd frontend && npm install && npm run build
    @echo "✅ Frontend build complete!"

# Build everything
build: build-backend build-frontend
    @echo "✅ All builds complete!"

# Run the backend only
run-backend: build-backend
    @echo "🚀 Starting backend on port 8080..."
    @cd backend && ./zig-out/bin/xeetapus-backend

# Run the frontend only (Vite dev server)
run-frontend:
    @echo "🚀 Starting React frontend on port 3000..."
    @cd frontend && npm run dev

# Run both backend and frontend (production mode)
run:
    @echo "🐙 Starting Xeetapus..."
    @just stop 2>/dev/null || true
    @just build
    @echo "🚀 Starting services..."
    @cd backend && ./zig-out/bin/xeetapus-backend &
    @sleep 3
    @cd frontend && npx serve dist -p 3000 &
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
    @cd backend && ./zig-out/bin/xeetapus-backend &
    @sleep 2
    @cd frontend && npm run dev &
    @echo ""
    @echo "✅ Xeetapus is running!"
    @echo "   Backend:  http://localhost:8080"
    @echo "   Frontend: http://localhost:3000"
    @echo ""
    @echo "Press Ctrl+C to stop"
    @wait
