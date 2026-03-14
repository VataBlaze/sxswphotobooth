#!/usr/bin/env bash
# ============================================================================
# SXSW Vaporwave ₿ Photobooth — Setup Script
#
# Installs the app FROM THIS REPO (not PyPI), copies theme/userdata files
# to the data directory, and configures the system.
#
# Works on: Raspberry Pi 4/5 (64-bit), Ubuntu 22/24, Debian 12+
# Usage:    chmod +x setup.sh && ./setup.sh
# ============================================================================
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/photobooth-data"
FONT_DIR="$DATA_DIR/userdata/fonts"

IS_PI=false
if grep -qi "raspberry" /proc/device-tree/model 2>/dev/null || \
   grep -qi "raspberry" /proc/cpuinfo 2>/dev/null; then
  IS_PI=true
fi

IS_UBUNTU=false
if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
  IS_UBUNTU=true
fi

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   VAPORWAVE ₿ PHOTOBOOTH — SETUP                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ "$IS_PI" = true ]; then echo "  Platform: Raspberry Pi"
elif [ "$IS_UBUNTU" = true ]; then echo "  Platform: Ubuntu"
else echo "  Platform: Linux (Debian-based)"; fi
echo "  Source:   $REPO_DIR"
echo "  Data:     $DATA_DIR"
echo ""

# ==================================================================
# 1. System dependencies (split into groups so one failure doesn't
#    block the rest)
# ==================================================================
echo "[1/8] Installing system dependencies..."
sudo apt update

echo "  Core packages..."
sudo apt -y install \
  python3-dev python3-pip python3-venv \
  ffmpeg libgl1 curl git \
  fonts-noto-color-emoji 2>/dev/null || true

echo "  pipx..."
if ! command -v pipx &>/dev/null; then
  sudo apt -y install pipx 2>/dev/null || \
  python3 -m pip install --user pipx --break-system-packages 2>/dev/null || \
  python3 -m pip install --user pipx 2>/dev/null || {
    echo "  FATAL: Could not install pipx."
    exit 1
  }
fi

echo "  libjpeg-turbo..."
sudo apt -y install libturbojpeg0 2>/dev/null || \
sudo apt -y install libjpeg-turbo8 2>/dev/null || \
sudo apt -y install libjpeg62-turbo 2>/dev/null || true

echo "  Printing..."
sudo apt -y install cups cups-client printer-driver-gutenprint 2>/dev/null || true

echo "  Camera/video tools..."
sudo apt -y install v4l-utils 2>/dev/null || true
if [ "$IS_PI" = true ]; then
  sudo apt -y install libgphoto2-dev libgphoto2-6 libgphoto2-port12 libexif12 libltdl7 2>/dev/null || true
fi

echo "  Font tools..."
sudo apt -y install woff2 2>/dev/null || true
pip install --break-system-packages brotli fonttools Pillow 2>/dev/null || \
python3 -m pip install --user brotli fonttools Pillow 2>/dev/null || true

# ==================================================================
# 2. pipx ensurepath
# ==================================================================
echo "[2/8] Configuring pipx PATH..."
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath 2>/dev/null || true

# ==================================================================
# 3. WiFi power-save (Pi only)
# ==================================================================
if [ "$IS_PI" = true ]; then
  echo "[3/8] Disabling WiFi power-save..."
  WIFI_CMD="iw dev wlan0 set power_save off"
  RCLOCAL="/etc/rc.local"
  if [ ! -f "$RCLOCAL" ]; then
    sudo bash -c "printf '#!/bin/sh -e\n${WIFI_CMD}\nexit 0\n' > $RCLOCAL"
    sudo chmod +x "$RCLOCAL"
  elif ! grep -qF "$WIFI_CMD" "$RCLOCAL"; then
    sudo sed -i "/^exit 0/i $WIFI_CMD" "$RCLOCAL" 2>/dev/null || \
    echo "$WIFI_CMD" | sudo tee -a "$RCLOCAL" > /dev/null
  fi
else
  echo "[3/8] Skipping WiFi fix (not a Pi)."
fi

# ==================================================================
# 4. Create data directories
# ==================================================================
echo "[4/8] Creating data directories..."
mkdir -p "$DATA_DIR"/{userdata/fonts,userdata/frames,log,config,media,tmp}
echo "  ✓ $DATA_DIR/"

# ==================================================================
# 5. Download and convert fonts
# ==================================================================
echo "[5/8] Downloading fonts..."
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
  [ -f "$woff2_name" ] && continue
  curl -fsSL -o "$filename" "${FONT_URLS[$filename]}" 2>/dev/null || continue
  if command -v woff2_compress &>/dev/null; then
    woff2_compress "$filename" 2>/dev/null && rm -f "$filename"
  elif python3 -c "from fontTools.ttLib import TTFont; f=TTFont('$filename'); f.flavor='woff2'; f.save('$woff2_name'); f.close()" 2>/dev/null; then
    rm -f "$filename"
  fi
  [ -f "$woff2_name" ] && echo "  ✓ $woff2_name"
done
cd "$REPO_DIR"

# ==================================================================
# 6. Copy userdata files from repo to data directory
# ==================================================================
echo "[6/8] Copying userdata files..."
for f in private.css breathing.html breathe-button.js; do
  if [ -f "$REPO_DIR/userdata/$f" ]; then
    cp "$REPO_DIR/userdata/$f" "$DATA_DIR/userdata/$f"
    echo "  ✓ $f"
  else
    echo "  ✗ userdata/$f not found in repo!"
  fi
done

# ==================================================================
# 7. Install photobooth-app FROM THIS REPO
# ==================================================================
echo "[7/8] Installing photobooth-app from local source..."
if pipx list 2>/dev/null | grep -q "photobooth-app"; then
  echo "  Removing previous PyPI installation..."
  pipx uninstall photobooth-app 2>/dev/null || true
fi

# Install from the local repo source code
if [ "$IS_PI" = true ]; then
  pipx install --system-site-packages "$REPO_DIR" --pip-args='--prefer-binary'
else
  pipx install --system-site-packages "$REPO_DIR" --pip-args='--prefer-binary' 2>/dev/null || \
  pipx install "$REPO_DIR" --pip-args='--prefer-binary'
fi

if command -v photobooth &>/dev/null || [ -f "$HOME/.local/bin/photobooth" ]; then
  echo "  ✓ photobooth installed from local source"
else
  echo "  ✗ photobooth command not found — open a new terminal and retry"
fi

# ==================================================================
# 8. Generate frame overlay
# ==================================================================
echo "[8/8] Generating frame overlay..."
if python3 "$REPO_DIR/scripts/generate-frame.py" 2>/dev/null; then
  echo "  ✓ Frame overlay generated"
else
  echo "  Frame skipped (install Pillow: pip install Pillow --break-system-packages)"
fi

# ==================================================================
# Done
# ==================================================================
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   SETUP COMPLETE                                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  1. Open a NEW terminal (or: source ~/.bashrc)"
echo "  2. cd ~/photobooth-data && photobooth"
echo "  3. Open http://localhost:8000"
echo "  4. Configure camera: gear icon → password 0000 → Camera"
echo "  5. Diagnose hardware: bash $REPO_DIR/scripts/diagnose-hardware.sh"
if [ "$IS_PI" = true ]; then
  echo "  6. Deploy kiosk: bash $REPO_DIR/deploy/install-service.sh && sudo reboot"
fi
echo ""
