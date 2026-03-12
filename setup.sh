#!/usr/bin/env bash
# ============================================================================
# SXSW Vaporwave ₿ Photobooth — System Setup Script
# Run on a fresh 64-bit Raspberry Pi OS (Bookworm or Trixie)
# Usage:  chmod +x setup.sh && ./setup.sh
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/photobooth-data"
FONT_DIR="$DATA_DIR/userdata/fonts"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   VAPORWAVE ₿ PHOTOBOOTH — SYSTEM SETUP         ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# ------------------------------------------------------------------
# 1. System update
# ------------------------------------------------------------------
echo "[1/8] Updating system packages..."
sudo apt update && sudo apt -y upgrade

# ------------------------------------------------------------------
# 2. Install all system dependencies
# ------------------------------------------------------------------
echo "[2/8] Installing system dependencies..."
sudo apt -y install \
  ffmpeg \
  libturbojpeg0 \
  libgl1 \
  libgphoto2-dev \
  fonts-noto-color-emoji \
  libexif12 \
  libgphoto2-6 \
  libgphoto2-port12 \
  libltdl7 \
  python3-dev \
  pipx \
  cups \
  cups-client \
  printer-driver-gutenprint \
  fonttools \
  woff2 \
  chromium-browser || sudo apt -y install chromium

# ------------------------------------------------------------------
# 3. pipx ensurepath
# ------------------------------------------------------------------
echo "[3/8] Ensuring pipx path..."
pipx ensurepath

# Reload PATH for this session
export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------------
# 4. Disable WiFi power-save (idempotent)
# ------------------------------------------------------------------
echo "[4/8] Disabling WiFi power-save..."
RCLOCAL="/etc/rc.local"
WIFI_CMD="iw dev wlan0 set power_save off"

if [ ! -f "$RCLOCAL" ]; then
  sudo bash -c "cat > $RCLOCAL" <<'RCEOF'
#!/bin/sh -e
iw dev wlan0 set power_save off
exit 0
RCEOF
  sudo chmod +x "$RCLOCAL"
  echo "  Created $RCLOCAL with WiFi power-save fix."
elif ! grep -qF "$WIFI_CMD" "$RCLOCAL"; then
  # Insert before 'exit 0' if present, otherwise append
  if grep -q "^exit 0" "$RCLOCAL"; then
    sudo sed -i "/^exit 0/i $WIFI_CMD" "$RCLOCAL"
  else
    echo "$WIFI_CMD" | sudo tee -a "$RCLOCAL" > /dev/null
  fi
  echo "  Added WiFi power-save fix to $RCLOCAL."
else
  echo "  WiFi power-save fix already present in $RCLOCAL."
fi

# ------------------------------------------------------------------
# 5. Create data directory structure
# ------------------------------------------------------------------
echo "[5/8] Creating photobooth data directories..."
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/userdata/fonts"
mkdir -p "$DATA_DIR/userdata/frames"
mkdir -p "$DATA_DIR/plugins/breathing_session"

# ------------------------------------------------------------------
# 6. Download and convert fonts
# ------------------------------------------------------------------
echo "[6/8] Downloading and converting fonts..."

# We need pip-installed fonttools with woff2 support for conversion
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
  curl -fsSL -o "$filename" "${FONT_URLS[$filename]}"
  echo "  Converting $filename to woff2..."
  # fonttools provides pyftsubset; woff2_compress from the woff2 package
  if command -v woff2_compress &> /dev/null; then
    woff2_compress "$filename"
  else
    # Fallback: use fonttools to convert
    python3 -c "
from fontTools.ttLib import TTFont
font = TTFont('$filename')
font.flavor = 'woff2'
font.save('$woff2_name')
font.close()
"
  fi
  # Remove the .ttf source to save space
  rm -f "$filename"
  echo "  Created $woff2_name"
done

cd "$REPO_DIR"

# ------------------------------------------------------------------
# 7. Copy userdata files from repo into data directory
# ------------------------------------------------------------------
echo "[7/8] Copying theme and plugin files..."

# Copy private.css
if [ -f "$REPO_DIR/userdata/private.css" ]; then
  cp "$REPO_DIR/userdata/private.css" "$DATA_DIR/userdata/private.css"
  echo "  Copied private.css"
fi

# Copy breathing.html
if [ -f "$REPO_DIR/userdata/breathing.html" ]; then
  cp "$REPO_DIR/userdata/breathing.html" "$DATA_DIR/userdata/breathing.html"
  echo "  Copied breathing.html"
fi

# Copy plugin files
if [ -d "$REPO_DIR/plugins/breathing_session" ]; then
  cp -r "$REPO_DIR/plugins/breathing_session/"* "$DATA_DIR/plugins/breathing_session/"
  echo "  Copied breathing_session plugin"
fi

# ------------------------------------------------------------------
# 8. Install photobooth-app
# ------------------------------------------------------------------
echo "[8/8] Installing photobooth-app via pipx..."

# If installing from a local clone of the repo:
if [ -f "$REPO_DIR/pyproject.toml" ]; then
  pipx install --system-site-packages "$REPO_DIR" --pip-args='--prefer-binary'
# Otherwise install from PyPI as fallback:
else
  echo "  No pyproject.toml found in repo root. Installing from PyPI..."
  pipx install --system-site-packages photobooth-app --pip-args='--prefer-binary'
fi

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   SETUP COMPLETE                                ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Restart your terminal (or run: source ~/.bashrc)"
echo "     so the pipx PATH update takes effect."
echo ""
echo "  2. Start the photobooth for first-time configuration:"
echo "       cd ~/photobooth-data && photobooth"
echo ""
echo "  3. Open http://localhost:8000 in a browser."
echo "     Go to Admin Center to configure your camera."
echo ""
echo "  4. Set up your printer:"
echo "       See printer-setup.md in the repo root."
echo ""
echo "  5. Deploy as a kiosk service:"
echo "       cd $REPO_DIR && bash deploy/install-service.sh"
echo ""
echo "  6. Reboot and enjoy your Vaporwave ₿ Photobooth!"
echo ""
