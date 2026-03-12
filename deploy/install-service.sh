#!/usr/bin/env bash
# ============================================================================
# install-service.sh — Installs systemd user service + kiosk autostart
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="photobooth-app.service"
SERVICE_SRC="$SCRIPT_DIR/$SERVICE_NAME"
SERVICE_DST="$HOME/.local/share/systemd/user/$SERVICE_NAME"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   INSTALLING PHOTOBOOTH SERVICE                  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# 1. Copy service file
echo "[1/5] Installing systemd user service..."
mkdir -p "$(dirname "$SERVICE_DST")"
cp "$SERVICE_SRC" "$SERVICE_DST"
echo "  → $SERVICE_DST"

# 2. Reload
echo "[2/5] Reloading systemd..."
systemctl --user daemon-reload

# 3. Enable + start
echo "[3/5] Enabling and starting service..."
systemctl --user enable "$SERVICE_NAME"
systemctl --user start "$SERVICE_NAME"
sleep 3
if systemctl --user is-active --quiet "$SERVICE_NAME"; then
  echo "  ✓ Service is running."
else
  echo "  ✗ Service may not have started. Check:"
  echo "    journalctl --user -u $SERVICE_NAME -n 20"
fi

# 4. Kiosk
echo "[4/5] Configuring kiosk autostart..."
bash "$SCRIPT_DIR/kiosk-autostart.sh"

# 5. Lingering
echo "[5/5] Enabling lingering (start at boot without login)..."
loginctl enable-linger "$USER"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   DONE — Reboot to verify                       ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Commands:"
echo "    systemctl --user status photobooth-app"
echo "    systemctl --user restart photobooth-app"
echo "    journalctl --user -u photobooth-app -f"
echo ""
echo "  sudo reboot"
echo ""
