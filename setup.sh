#!/usr/bin/env bash
# ============================================================================
# SXSW Vaporwave ₿ Photobooth — Setup Script
#
# Works on:
#   - Raspberry Pi 4/5 (64-bit Raspberry Pi OS Bookworm/Trixie)
#   - Ubuntu 22.04 / 24.04 laptop/desktop
#   - Debian 12+ laptop/desktop
#
# Usage:  chmod +x setup.sh && ./setup.sh
# ============================================================================
set -uo pipefail
# NOTE: we use set -u (undefined vars are errors) but NOT set -e
# so that individual apt/pip failures don't kill the whole script.

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

# Detect Ubuntu vs Debian/Pi OS
IS_UBUNTU=false
if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  IS_UBUNTU=true
fi

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   VAPORWAVE ₿ PHOTOBOOTH — SETUP                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ "$IS_PI" = true ]; then
  echo "  Platform: Raspberry Pi"
elif [ "$IS_UBUNTU" = true ]; then
  echo "  Platform: Ubuntu"
else
  echo "  Platform: Linux (Debian-based)"
fi
echo "  Repo:     $REPO_DIR"
echo "  Data:     $DATA_DIR"
echo ""

# ------------------------------------------------------------------
# 1. System update
# ------------------------------------------------------------------
echo "[1/9] Updating package lists..."
sudo apt update

# ------------------------------------------------------------------
# 2. Install dependencies (split into groups so one failure doesn't
#    block the rest)
# ------------------------------------------------------------------
echo "[2/9] Installing system dependencies..."

# --- Group A: Core (required) ---
echo "  Installing core packages..."
sudo apt -y install \
  python3-dev python3-pip python3-venv \
  ffmpeg libgl1 curl git \
  fonts-noto-color-emoji

# --- Group B: pipx (critical — needed to install photobooth-app) ---
echo "  Installing pipx..."
if ! command -v pipx &>/dev/null; then
  # Try apt first
  if sudo apt -y install pipx 2>/dev/null; then
    echo "  pipx installed via apt."
  else
    # Fallback: install pipx via pip
    echo "  apt pipx not available, installing via pip..."
    python3 -m pip install --user pipx --break-system-packages 2>/dev/null || \
    python3 -m pip install --user pipx 2>/dev/null || {
      echo "  ERROR: Could not install pipx. Install manually:"
      echo "    sudo apt install pipx"
      echo "    OR: python3 -m pip install --user pipx"
      exit 1
    }
  fi
fi

# --- Group C: libjpeg-turbo (package name varies by distro) ---
echo "  Installing libjpeg-turbo..."
# Try all known package names — one of them will work
sudo apt -y install libturbojpeg0 2>/dev/null || \
sudo apt -y install libturbojpeg0-dev 2>/dev/null || \
sudo apt -y install libjpeg-turbo8 2>/dev/null || \
sudo apt -y install libjpeg-turbo8-dev 2>/dev/null || \
sudo apt -y install libjpeg62-turbo 2>/dev/null || \
echo "  (libjpeg-turbo: no matching package found — may already be installed)"

# --- Group D: Printing ---
echo "  Installing printing packages..."
sudo apt -y install cups cups-client printer-driver-gutenprint 2>/dev/null || \
echo "  (Some printing packages unavailable — install manually if needed)"

# --- Group E: Camera + video tools ---
echo "  Installing camera/video tools..."
sudo apt -y install v4l-utils 2>/dev/null || true

if [ "$IS_PI" = true ]; then
  echo "  Installing Pi camera packages..."
  sudo apt -y install libgphoto2-dev libgphoto2-6 libgphoto2-port12 2>/dev/null || true
  sudo apt -y install libexif12 libltdl7 2>/dev/null || true
fi

# --- Group F: Font conversion tools ---
echo "  Installing font tools..."
sudo apt -y install woff2 2>/dev/null || true
# fonttools via pip (needed for woff2 conversion fallback)
pip install --break-system-packages brotli fonttools 2>/dev/null || \
python3 -m pip install --user brotli fonttools 2>/dev/null || true

# --- Group G: Pillow for frame generation ---
echo "  Installing Pillow..."
pip install --break-system-packages Pillow 2>/dev/null || \
python3 -m pip install --user Pillow 2>/dev/null || true

echo "  Dependencies installed."
echo ""

# ------------------------------------------------------------------
# 3. pipx ensurepath
# ------------------------------------------------------------------
echo "[3/9] Configuring pipx PATH..."
# Find pipx wherever it landed
export PATH="$HOME/.local/bin:$PATH"
if command -v pipx &>/dev/null; then
  pipx ensurepath
  echo "  pipx is at: $(which pipx)"
else
  echo "  ERROR: pipx still not found after installation."
  echo "  Try opening a new terminal and re-running this script."
  exit 1
fi

# ------------------------------------------------------------------
# 4. WiFi power-save fix (Pi only)
# ------------------------------------------------------------------
if [ "$IS_PI" = true ]; then
  echo "[4/9] Disabling WiFi power-save (Pi only)..."
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
  echo "[4/9] Skipping WiFi fix (not a Pi)."
fi

# ------------------------------------------------------------------
# 5. Create ALL data directories
# ------------------------------------------------------------------
echo "[5/9] Creating data directories..."
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/userdata/fonts"
mkdir -p "$DATA_DIR/userdata/frames"
mkdir -p "$DATA_DIR/plugins/breathing_session"
mkdir -p "$DATA_DIR/log"
mkdir -p "$DATA_DIR/config"
mkdir -p "$DATA_DIR/media"
echo "  Created: $DATA_DIR/"

# ------------------------------------------------------------------
# 6. Download and convert fonts
# ------------------------------------------------------------------
echo "[6/9] Downloading fonts..."

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
  if ! curl -fsSL -o "$filename" "${FONT_URLS[$filename]}"; then
    echo "  WARNING: Failed to download $filename — skipping."
    continue
  fi
  echo "  Converting to woff2..."
  if command -v woff2_compress &>/dev/null; then
    woff2_compress "$filename" 2>/dev/null && rm -f "$filename"
  elif python3 -c "from fontTools.ttLib import TTFont" 2>/dev/null; then
    python3 -c "
from fontTools.ttLib import TTFont
font = TTFont('$filename')
font.flavor = 'woff2'
font.save('$woff2_name')
font.close()
" && rm -f "$filename"
  else
    echo "  WARNING: No woff2 converter available. Keeping .ttf file."
  fi
  [ -f "$woff2_name" ] && echo "  ✓ $woff2_name"
done
cd "$REPO_DIR"

# ------------------------------------------------------------------
# 7. Copy ALL customization files
# ------------------------------------------------------------------
echo "[7/9] Copying customization files..."

cp "$REPO_DIR/userdata/private.css"       "$DATA_DIR/userdata/private.css"
cp "$REPO_DIR/userdata/breathing.html"    "$DATA_DIR/userdata/breathing.html"
cp "$REPO_DIR/userdata/breathe-button.js" "$DATA_DIR/userdata/breathe-button.js"

cp "$REPO_DIR/plugins/breathing_session/__init__.py"          "$DATA_DIR/plugins/breathing_session/"
cp "$REPO_DIR/plugins/breathing_session/breathing_session.py" "$DATA_DIR/plugins/breathing_session/"
cp "$REPO_DIR/plugins/breathing_session/config.py"            "$DATA_DIR/plugins/breathing_session/"

if [ -f "$REPO_DIR/userdata/frames/vaporwave-btc-frame.png" ]; then
  cp "$REPO_DIR/userdata/frames/vaporwave-btc-frame.png" "$DATA_DIR/userdata/frames/"
fi

echo "  ✓ private.css"
echo "  ✓ breathing.html"
echo "  ✓ breathe-button.js"
echo "  ✓ breathing_session plugin (3 files)"
echo "  ✓ frame overlay (if present)"

# ------------------------------------------------------------------
# 8. Install photobooth-app from PyPI
# ------------------------------------------------------------------
echo "[8/9] Installing photobooth-app..."
if pipx list 2>/dev/null | grep -q "photobooth-app"; then
  echo "  Already installed. Upgrading..."
  pipx upgrade photobooth-app --pip-args='--prefer-binary' 2>/dev/null || true
else
  if [ "$IS_PI" = true ]; then
    pipx install --system-site-packages photobooth-app --pip-args='--prefer-binary'
  else
    # On non-Pi, --system-site-packages may not be needed but doesn't hurt
    pipx install --system-site-packages photobooth-app --pip-args='--prefer-binary' 2>/dev/null || \
    pipx install photobooth-app --pip-args='--prefer-binary'
  fi
fi

# Verify
if command -v photobooth &>/dev/null || [ -f "$HOME/.local/bin/photobooth" ]; then
  echo "  ✓ photobooth-app installed."
else
  echo "  WARNING: 'photobooth' command not found in PATH."
  echo "  Open a new terminal and run:  which photobooth"
fi

# ------------------------------------------------------------------
# 9. Generate frame overlay + patch BREATHE button
# ------------------------------------------------------------------
echo "[9/9] Final setup steps..."

# Generate frame
if python3 "$REPO_DIR/scripts/generate-frame.py" 2>/dev/null; then
  echo "  ✓ Frame overlay generated."
else
  echo "  Frame overlay skipped (Pillow not available — run later)."
fi

# Patch index.html
echo ""
bash "$REPO_DIR/scripts/patch-breathe-button.sh" 2>/dev/null || {
  echo "  BREATHE button patch will be applied after first start."
  echo "  Re-run later:  bash $REPO_DIR/scripts/patch-breathe-button.sh"
}

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   SETUP COMPLETE                                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  What to do now:"
echo ""
echo "  1. Open a NEW terminal (so PATH is updated)"
echo ""
echo "  2. Start the photobooth:"
echo "       cd ~/photobooth-data && photobooth"
echo ""
echo "  3. Open http://localhost:8000 in your browser"
echo ""
echo "  4. Configure your camera:"
echo "       Click gear icon → password 0000"
echo "       CONFIGURATION → Camera → set Backend type"
echo ""
echo "  5. Need help detecting your camera?"
echo "       bash $REPO_DIR/scripts/diagnose-hardware.sh"
echo ""
if [ "$IS_PI" = true ]; then
  echo "  6. Deploy as kiosk (after camera works):"
  echo "       bash $REPO_DIR/deploy/install-service.sh"
  echo "       sudo reboot"
  echo ""
fi
