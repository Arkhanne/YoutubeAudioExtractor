#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/../deps"
mkdir -p "$DEPS_DIR"

ARCH=$(uname -m)

# ── yt-dlp (universal macOS binary) ──────────────────────────────────────────
if [ ! -f "$DEPS_DIR/yt-dlp" ]; then
    echo "→ Downloading yt-dlp..."
    curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
        -o "$DEPS_DIR/yt-dlp"
    chmod +x "$DEPS_DIR/yt-dlp"
    xattr -d com.apple.quarantine "$DEPS_DIR/yt-dlp" 2>/dev/null || true
    echo "✓ yt-dlp ready"
else
    echo "✓ yt-dlp already present"
fi

# ── ffmpeg (static build) ─────────────────────────────────────────────────────
if [ ! -f "$DEPS_DIR/ffmpeg" ]; then
    echo "→ Downloading ffmpeg ($ARCH)..."
    TMP_ZIP=$(mktemp /tmp/ffmpeg_XXXXXX.zip)

    if [ "$ARCH" = "arm64" ]; then
        # Apple Silicon — static build from osxexperts.net
        curl -fsSL "https://www.osxexperts.net/ffmpeg7arm.zip" -o "$TMP_ZIP"
    else
        # Intel — static build from evermeet.cx
        curl -fsSL "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip" -o "$TMP_ZIP"
    fi

    unzip -o "$TMP_ZIP" ffmpeg -d "$DEPS_DIR/"
    rm "$TMP_ZIP"
    chmod +x "$DEPS_DIR/ffmpeg"
    xattr -d com.apple.quarantine "$DEPS_DIR/ffmpeg" 2>/dev/null || true
    echo "✓ ffmpeg ready"
else
    echo "✓ ffmpeg already present"
fi
