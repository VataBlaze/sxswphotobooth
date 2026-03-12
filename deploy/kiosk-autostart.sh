#!/usr/bin/env bash
# ============================================================================
# kiosk-autostart.sh — Pi only (laptops don't need kiosk mode)
# Configures Chromium to open in fullscreen on boot.
# ============================================================================
set -euo pipefail

BOOTH_URL="http://localhost:8000/"

# Detect Chromium binary
CHROMIUM=""
for bin in chromium-browser chromium google-chrome; do
  if command -v "$bin" &>/dev/null; then CHROMIUM="$bin"; break; fi
done
if [ -z "$CHROMIUM" ]; then
  echo "ERROR: No Chromium/Chrome found. Install: sudo apt install chromium-browser"
  exit 1
fi

KIOSK_CMD="bash -c 'while ! curl -s -o /dev/null ${BOOTH_URL}; do sleep 2; done; ${CHROMIUM} --kiosk --noerrdialogs --disable-infobars --disable-translate --no-first-run --disable-session-crashed-bubble --autoplay-policy=no-user-gesture-required ${BOOTH_URL}'"

# Detect compositor and write autostart
if [ -d "$HOME/.config/labwc" ] || pgrep -x labwc &>/dev/null; then
  AUTOSTART_FILE="$HOME/.config/labwc/autostart"
  mkdir -p "$(dirname "$AUTOSTART_FILE")"
  [ -f "$AUTOSTART_FILE" ] && grep -v "# photobooth-kiosk" "$AUTOSTART_FILE" > "${AUTOSTART_FILE}.tmp" 2>/dev/null && mv "${AUTOSTART_FILE}.tmp" "$AUTOSTART_FILE" || true
  echo "${KIOSK_CMD} & # photobooth-kiosk" >> "$AUTOSTART_FILE"
  echo "  Wrote labwc autostart: $AUTOSTART_FILE"

elif [ -f "$HOME/.config/wayfire.ini" ] || pgrep -x wayfire &>/dev/null; then
  WAYFIRE_INI="$HOME/.config/wayfire.ini"
  sed -i '/^photobooth_kiosk/d' "$WAYFIRE_INI" 2>/dev/null || true
  if grep -q '^\[autostart\]' "$WAYFIRE_INI" 2>/dev/null; then
    sed -i "/^\[autostart\]/a photobooth_kiosk = ${KIOSK_CMD}" "$WAYFIRE_INI"
  else
    printf '\n[autostart]\nphotobooth_kiosk = %s\n' "$KIOSK_CMD" >> "$WAYFIRE_INI"
  fi
  echo "  Wrote wayfire autostart: $WAYFIRE_INI"

else
  AUTOSTART_DIR="$HOME/.config/autostart"
  mkdir -p "$AUTOSTART_DIR"
  cat > "$AUTOSTART_DIR/photobooth-kiosk.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Photobooth Kiosk
Exec=bash -c 'while ! curl -s -o /dev/null ${BOOTH_URL}; do sleep 2; done; ${CHROMIUM} --kiosk --noerrdialogs --disable-infobars --no-first-run ${BOOTH_URL}'
X-GNOME-Autostart-enabled=true
DESKTOP
  echo "  Created XDG autostart: $AUTOSTART_DIR/photobooth-kiosk.desktop"
fi

echo "  Kiosk configured: $CHROMIUM → $BOOTH_URL"
