#!/usr/bin/env bash
# ============================================================================
# SXSW Vaporwave ₿ Photobooth — Setup Script
#
# Works on:
#   - Raspberry Pi 4/5 (64-bit Raspberry Pi OS Bookworm/Trixie)
#   - Any Linux laptop/desktop (Ubuntu, Debian, Fedora, etc.)
#
# Usage:  chmod +x setup.sh && ./setup.sh
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/photobooth-data"
FONT_DIR="$DATA_DIR/userdata/fonts"

# ------------------------------------------------------------------
# Detect platform
# ------------------------------------------------------------------
IS_PI=false
if grep -qi "raspberry" /proc/device-tree/model 2>/dev/null || \
   grep -qi "raspberry" /proc/cpuinfo 2>/dev/null; then
  IS_PI=true
fi

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   VAPORWAVE ₿ PHOTOBOOTH — SETUP                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ "$IS_PI" = true ]; then
  echo "  Platform: Raspberry Pi"
else
  echo "  Platform: Linux laptop/desktop"
fi
echo "  Repo:     $REPO_DIR"
echo "  Data:     $DATA_DIR"
echo ""

# ------------------------------------------------------------------
# 1. System update + dependencies
# ------------------------------------------------------------------
echo "[1/9] Installing system dependencies..."
sudo apt update

PACKAGES=(
  ffmpeg libturbojpeg0 libgl1 fonts-noto-color-emoji
  libexif12 libltdl7 python3-dev pipx
  cups cups-client printer-driver-gutenprint
  curl
)

# Pi-specific packages
if [ "$IS_PI" = true ]; then
  PACKAGES+=(libgphoto2-dev libgphoto2-6 libgphoto2-port12)
fi

# Webcam tools (useful on both laptop and Pi)
PACKAGES+=(v4l-utils)

# woff2 conversion tools
PACKAGES+=(fonttools woff2)

# Chromium (name varies by distro)
if apt-cache show chromium-browser &>/dev/null 2>&1; then
  PACKAGES+=(chromium-browser)
elif apt-cache show chromium &>/dev/null 2>&1; then
  PACKAGES+=(chromium)
fi

sudo apt -y install "${PACKAGES[@]}" || {
  echo "  Some packages may not be available on your distro."
  echo "  Continuing with what's installed..."
}

# ------------------------------------------------------------------
# 2. pipx ensurepath
# ------------------------------------------------------------------
echo "[2/9] Configuring pipx..."
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------------
# 3. WiFi power-save fix (Pi only)
# ------------------------------------------------------------------
if [ "$IS_PI" = true ]; then
  echo "[3/9] Disabling WiFi power-save (Pi only)..."
  RCLOCAL="/etc/rc.local"
  WIFI_CMD="iw dev wlan0 set power_save off"
  if [ ! -f "$RCLOCAL" ]; then
    sudo bash -c "printf '#!/bin/sh -e\n${WIFI_CMD}\nexit 0\n' > $RCLOCAL"
    sudo chmod +x "$RCLOCAL"
  elif ! grep -qF "$WIFI_CMD" "$RCLOCAL"; then
    if grep -q "^exit 0" "$RCLOCAL"; then
      sudo sed -i "/^exit 0/i $WIFI_CMD" "$RCLOCAL"
    else
      echo "$WIFI_CMD" | sudo tee -a "$RCLOCAL" > /dev/null
    fi
  fi
else
  echo "[3/9] Skipping WiFi power-save fix (not a Pi)."
fi

# ------------------------------------------------------------------
# 4. Create ALL data directories
# ------------------------------------------------------------------
echo "[4/9] Creating photobooth data directories..."
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/userdata/fonts"
mkdir -p "$DATA_DIR/userdata/frames"
mkdir -p "$DATA_DIR/plugins/breathing_session"
mkdir -p "$DATA_DIR/log"
mkdir -p "$DATA_DIR/config"
mkdir -p "$DATA_DIR/media"
echo "  Created: $DATA_DIR and all subdirectories."

# ------------------------------------------------------------------
# 5. Download and convert fonts
# ------------------------------------------------------------------
echo "[5/9] Downloading and converting fonts..."
pip install --break-system-packages brotli 2>/dev/null || true

GOOGLE_FONTS_BASE="https://github.com/google/fonts/raw/main"

declare -A FONT_URLS=(
  ["PressStart2P-Regular.ttf"]="$GOOGLE_FONTS_BASE/ofl/pressstart2p/PressStart2P-Regular.ttf"
  ["VT323-Regular.ttf"]="$GOOGLE_FONTS_BASE/ofl/vt323/VT323-Regular.ttf"
  ["Monoton-Regular.ttf"]="$GOOGLE_FONTS_BASE/ofl/monoton/Monoton-Regular.ttf"
  ["SpaceMono-Regular.ttf"]="$GOOGLE_FONTS_BASE/ofl/spacemono/SpaceMono-Regular.ttf"
  ["SpaceMono-Bold.ttf"]="$GOOGLE_FONTS_BASE/ofl/spacemono/SpaceMono-Bold.ttf"
)

cd "$FONT_DIR"
for filename in "${!FONT_URLS[@]}"; do
  woff2_name="${filename%.ttf}.woff2"
  if [ -f "$woff2_name" ]; then
    echo "  $woff2_name already exists, skipping."
    continue
  fi
  echo "  Downloading $filename..."
  curl -fsSL -o "$filename" "${FONT_URLS[$filename]}" || {
    echo "  WARNING: Failed to download $filename — skipping."
    continue
  }
  echo "  Converting to woff2..."
  if command -v woff2_compress &>/dev/null; then
    woff2_compress "$filename" 2>/dev/null
  else
    python3 -c "
from fontTools.ttLib import TTFont
font = TTFont('$filename')
font.flavor = 'woff2'
font.save('$woff2_name')
font.close()
" 2>/dev/null || echo "  WARNING: woff2 conversion failed for $filename"
  fi
  rm -f "$filename"
  [ -f "$woff2_name" ] && echo "  Created $woff2_name"
done
cd "$REPO_DIR"

# ------------------------------------------------------------------
# 6. Copy ALL customization files to data directory
# ------------------------------------------------------------------
echo "[6/9] Copying theme, plugin, and page files..."

# Theme CSS
cp "$REPO_DIR/userdata/private.css" "$DATA_DIR/userdata/private.css"
echo "  Copied private.css"

# Breathing session page
cp "$REPO_DIR/userdata/breathing.html" "$DATA_DIR/userdata/breathing.html"
echo "  Copied breathing.html"

# Button injector script
cp "$REPO_DIR/userdata/breathe-button.js" "$DATA_DIR/userdata/breathe-button.js"
echo "  Copied breathe-button.js"

# Plugin files
cp "$REPO_DIR/plugins/breathing_session/__init__.py"          "$DATA_DIR/plugins/breathing_session/__init__.py"
cp "$REPO_DIR/plugins/breathing_session/breathing_session.py"  "$DATA_DIR/plugins/breathing_session/breathing_session.py"
cp "$REPO_DIR/plugins/breathing_session/config.py"             "$DATA_DIR/plugins/breathing_session/config.py"
echo "  Copied breathing_session plugin"

# Frame overlay (if exists — generated in step 8)
if [ -f "$REPO_DIR/userdata/frames/vaporwave-btc-frame.png" ]; then
  cp "$REPO_DIR/userdata/frames/vaporwave-btc-frame.png" "$DATA_DIR/userdata/frames/vaporwave-btc-frame.png"
  echo "  Copied frame overlay"
fi

# ------------------------------------------------------------------
# 7. Install photobooth-app from PyPI
# ------------------------------------------------------------------
echo "[7/9] Installing photobooth-app via pipx..."
if pipx list 2>/dev/null | grep -q "photobooth-app"; then
  echo "  photobooth-app already installed, upgrading..."
  pipx upgrade photobooth-app --pip-args='--prefer-binary' || true
else
  pipx install --system-site-packages photobooth-app --pip-args='--prefer-binary'
fi

# ------------------------------------------------------------------
# 8. Generate frame overlay PNG
# ------------------------------------------------------------------
echo "[8/9] Generating frame overlay..."
if python3 "$REPO_DIR/scripts/generate-frame.py" 2>/dev/null; then
  echo "  Frame overlay generated."
else
  echo "  Frame generation skipped (install Pillow: pip install Pillow --break-system-packages)"
fi

# ------------------------------------------------------------------
# 9. Patch the installed index.html for BREATHE button
# ------------------------------------------------------------------
echo "[9/9] Patching frontpage for BREATHE ₿ button..."
bash "$REPO_DIR/scripts/patch-breathe-button.sh" || {
  echo ""
  echo "  The patch will be applied after the first start."
  echo "  You can re-run:  bash scripts/patch-breathe-button.sh"
}

# ------------------------------------------------------------------
# Done — platform-specific next steps
# ------------------------------------------------------------------
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   SETUP COMPLETE                                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  STEP 1:  Open a new terminal (or run: source ~/.bashrc)"
echo ""
echo "  STEP 2:  Start the photobooth:"
echo "           cd ~/photobooth-data && photobooth"
echo ""
echo "  STEP 3:  Open http://localhost:8000 in your browser"
echo ""
echo "  STEP 4:  Configure your camera:"
echo "           Admin Center → CONFIGURATION → Camera"
echo "           (Run:  bash $REPO_DIR/scripts/diagnose-hardware.sh  for help)"
echo ""
if [ "$IS_PI" = true ]; then
  echo "  STEP 5:  Deploy as kiosk (Pi only, after camera works):"
  echo "           bash $REPO_DIR/deploy/install-service.sh"
  echo ""
  echo "  STEP 6:  sudo reboot"
fi
echo ""
