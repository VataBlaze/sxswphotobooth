#!/usr/bin/env bash
# ============================================================================
# install-service.sh
# Installs the photobooth systemd user service, enables kiosk autostart,
# and configures lingering so everything starts at boot without login.
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

# ------------------------------------------------------------------
# 1. Copy systemd service file
# ------------------------------------------------------------------
echo "[1/5] Installing systemd user service..."
mkdir -p "$(dirname "$SERVICE_DST")"
cp "$SERVICE_SRC" "$SERVICE_DST"
echo "  Copied to $SERVICE_DST"

# ------------------------------------------------------------------
# 2. Reload systemd
# ------------------------------------------------------------------
echo "[2/5] Reloading systemd user daemon..."
systemctl --user daemon-reload

# ------------------------------------------------------------------
# 3. Enable and start the service
# ------------------------------------------------------------------
echo "[3/5] Enabling and starting photobooth-app service..."
systemctl --user enable "$SERVICE_NAME"
systemctl --user start "$SERVICE_NAME"

# Brief wait, then check status
sleep 3
if systemctl --user is-active --quiet "$SERVICE_NAME"; then
  echo "  Service is running."
else
  echo "  WARNING: Service may not have started cleanly."
  echo "  Check with: journalctl --user -u $SERVICE_NAME -n 30"
fi

# ------------------------------------------------------------------
# 4. Configure kiosk autostart
# ------------------------------------------------------------------
echo "[4/5] Configuring kiosk autostart..."
bash "$SCRIPT_DIR/kiosk-autostart.sh"

# ------------------------------------------------------------------
# 5. Enable lingering (so user services start at boot without login)
# ------------------------------------------------------------------
echo "[5/5] Enabling user lingering..."
loginctl enable-linger "$USER"
echo "  Lingering enabled for $USER."

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   INSTALLATION COMPLETE                          ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  The photobooth will start automatically on boot."
echo ""
echo "  Useful commands:"
echo "    systemctl --user status photobooth-app"
echo "    systemctl --user restart photobooth-app"
echo "    journalctl --user -u photobooth-app -f"
echo ""
echo "  Reboot now to verify everything works:"
echo "    sudo reboot"
echo ""
