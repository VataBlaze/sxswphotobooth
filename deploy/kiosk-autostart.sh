#!/usr/bin/env bash
# ============================================================================
# kiosk-autostart.sh
# Configures Chromium kiosk mode for the Vaporwave ₿ Photobooth.
# Detects compositor (labwc or wayfire) and Chromium binary name.
# ============================================================================
set -euo pipefail

BOOTH_URL="http://localhost:8000/"
CHROMIUM=""
COMPOSITOR=""

# ------------------------------------------------------------------
# Detect Chromium binary
# ------------------------------------------------------------------
if command -v chromium-browser &>/dev/null; then
  CHROMIUM="chromium-browser"
elif command -v chromium &>/dev/null; then
  CHROMIUM="chromium"
else
  echo "ERROR: Neither chromium-browser nor chromium found."
  echo "Install with: sudo apt -y install chromium-browser"
  exit 1
fi
echo "Detected Chromium binary: $CHROMIUM"

# ------------------------------------------------------------------
# Build the kiosk launch command
# Polls localhost:8000 until the server is up, then launches Chromium.
# ------------------------------------------------------------------
KIOSK_CMD="bash -c 'while ! curl -s -o /dev/null ${BOOTH_URL}; do sleep 2; done; ${CHROMIUM} --kiosk --noerrdialogs --disable-infobars --disable-translate --no-first-run --disable-session-crashed-bubble --disable-component-update --check-for-update-interval=31536000 --autoplay-policy=no-user-gesture-required ${BOOTH_URL}'"

# ------------------------------------------------------------------
# Detect compositor and write autostart config
# ------------------------------------------------------------------
if [ -d "$HOME/.config/labwc" ] || pgrep -x labwc &>/dev/null; then
  COMPOSITOR="labwc"
  AUTOSTART_FILE="$HOME/.config/labwc/autostart"
  mkdir -p "$(dirname "$AUTOSTART_FILE")"

  # Remove any existing photobooth kiosk line
  if [ -f "$AUTOSTART_FILE" ]; then
    grep -v "# photobooth-kiosk" "$AUTOSTART_FILE" > "${AUTOSTART_FILE}.tmp" || true
    mv "${AUTOSTART_FILE}.tmp" "$AUTOSTART_FILE"
  fi

  echo "${KIOSK_CMD} & # photobooth-kiosk" >> "$AUTOSTART_FILE"
  echo "Wrote labwc autostart to $AUTOSTART_FILE"

elif [ -f "$HOME/.config/wayfire.ini" ] || pgrep -x wayfire &>/dev/null; then
  COMPOSITOR="wayfire"
  WAYFIRE_INI="$HOME/.config/wayfire.ini"

  # Check if [autostart] section exists
  if grep -q '^\[autostart\]' "$WAYFIRE_INI" 2>/dev/null; then
    # Remove any existing photobooth kiosk line
    sed -i '/^photobooth_kiosk/d' "$WAYFIRE_INI"
    # Append under [autostart]
    sed -i "/^\[autostart\]/a photobooth_kiosk = ${KIOSK_CMD}" "$WAYFIRE_INI"
  else
    # Add [autostart] section
    printf '\n[autostart]\nphotobooth_kiosk = %s\n' "$KIOSK_CMD" >> "$WAYFIRE_INI"
  fi
  echo "Wrote wayfire autostart to $WAYFIRE_INI"

else
  # Fallback: use XDG autostart (.desktop file)
  COMPOSITOR="unknown"
  AUTOSTART_DIR="$HOME/.config/autostart"
  mkdir -p "$AUTOSTART_DIR"
  cat > "$AUTOSTART_DIR/photobooth-kiosk.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Photobooth Kiosk
Exec=bash -c 'while ! curl -s -o /dev/null ${BOOTH_URL}; do sleep 2; done; ${CHROMIUM} --kiosk --noerrdialogs --disable-infobars --disable-translate --no-first-run ${BOOTH_URL}'
X-GNOME-Autostart-enabled=true
DESKTOP
  echo "No labwc or wayfire detected. Created XDG autostart desktop file."
  echo "File: $AUTOSTART_DIR/photobooth-kiosk.desktop"
fi

echo ""
echo "Kiosk autostart configured."
echo "  Compositor: $COMPOSITOR"
echo "  Chromium:   $CHROMIUM"
echo "  URL:        $BOOTH_URL"
echo ""
echo "The kiosk will launch on next graphical session start."
