#!/usr/bin/env bash
# ============================================================================
# diagnose-hardware.sh
#
# Detects available cameras and printers on the system, tests them, and
# prints the configuration steps needed for the photobooth-app Admin Center.
#
# Usage:  bash scripts/diagnose-hardware.sh
# ============================================================================
set -uo pipefail

DATA_DIR="$HOME/photobooth-data"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   HARDWARE DIAGNOSTICS                           ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# ==================================================================
# 1. CAMERA DETECTION
# ==================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CAMERAS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CAMERA_FOUND=false
CAMERA_TYPE=""

# --- Check for Raspberry Pi Camera Module (libcamera / picamera2) ---
echo "  [1] Checking for Raspberry Pi Camera Module..."
if command -v rpicam-hello &>/dev/null; then
  echo "      rpicam-hello is available."
  # Try to list cameras (non-interactive, immediate exit)
  PICAM_LIST=$(rpicam-hello --list-cameras 2>&1 || true)
  if echo "$PICAM_LIST" | grep -q "Available cameras"; then
    CAMERA_FOUND=true
    CAMERA_TYPE="picamera2"
    echo "      ✓ Pi Camera Module detected!"
    echo ""
    echo "      Camera info:"
    echo "$PICAM_LIST" | sed 's/^/        /'
    echo ""
    echo "      ┌─────────────────────────────────────────────────┐"
    echo "      │  ADMIN CENTER CONFIG:                           │"
    echo "      │  Backend type:  Picamera2                       │"
    echo "      │  Camera num:    0                               │"
    echo "      │                                                 │"
    echo "      │  For Camera Module 3 (recommended defaults):    │"
    echo "      │    Capture Resolution:  4608 × 2592             │"
    echo "      │    Preview Resolution:  2304 × 1296             │"
    echo "      │    Liveview Resolution: 1152 × 648              │"
    echo "      │                                                 │"
    echo "      │  For Camera Module 2:                           │"
    echo "      │    Capture Resolution:  3280 × 2464             │"
    echo "      │    Preview Resolution:  1640 × 1232             │"
    echo "      │    Liveview Resolution: 820 × 616               │"
    echo "      └─────────────────────────────────────────────────┘"
  else
    echo "      rpicam-hello found but no camera detected."
    echo "      Check the ribbon cable and run: rpicam-hello"
  fi
else
  echo "      rpicam-hello not found (not a Pi, or libcamera not installed)."
fi
echo ""

# --- Check for DSLR via gphoto2 ---
echo "  [2] Checking for DSLR cameras (gphoto2)..."
if command -v gphoto2 &>/dev/null; then
  echo "      gphoto2 is available."
  GPHOTO_DETECT=$(gphoto2 --auto-detect 2>&1 || true)
  # The output has a header line and dashes; actual cameras appear after
  GPHOTO_CAMERAS=$(echo "$GPHOTO_DETECT" | tail -n +3 | grep -v "^$" || true)
  if [ -n "$GPHOTO_CAMERAS" ]; then
    CAMERA_FOUND=true
    if [ -z "$CAMERA_TYPE" ]; then CAMERA_TYPE="gphoto2"; fi
    echo "      ✓ DSLR camera detected!"
    echo "$GPHOTO_CAMERAS" | sed 's/^/        /'
    echo ""
    echo "      ┌─────────────────────────────────────────────────┐"
    echo "      │  ADMIN CENTER CONFIG:                           │"
    echo "      │  Backend type:  Gphoto2                         │"
    echo "      │                                                 │"
    echo "      │  IMPORTANT: Kill any gphoto2 processes that     │"
    echo "      │  might lock the camera:                         │"
    echo "      │    pkill -f gphoto2                             │"
    echo "      │    pkill -f gvfs-gphoto2-volume-monitor         │"
    echo "      └─────────────────────────────────────────────────┘"
    echo ""
    echo "      To prevent the OS from auto-mounting the camera:"
    echo "        sudo systemctl mask gvfs-gphoto2-volume-monitor"
  else
    echo "      No DSLR cameras detected. Is the camera connected via USB and powered on?"
  fi
else
  echo "      gphoto2 not installed. Install with: sudo apt install gphoto2 libgphoto2-dev"
fi
echo ""

# --- Check for USB webcams (V4L2) ---
echo "  [3] Checking for USB webcams (V4L2)..."
if command -v v4l2-ctl &>/dev/null; then
  V4L_DEVICES=$(v4l2-ctl --list-devices 2>&1 || true)
  if echo "$V4L_DEVICES" | grep -q "/dev/video"; then
    CAMERA_FOUND=true
    if [ -z "$CAMERA_TYPE" ]; then CAMERA_TYPE="v4l2"; fi
    echo "      ✓ USB webcam(s) detected!"
    echo "$V4L_DEVICES" | sed 's/^/        /'
    echo ""
    echo "      ┌─────────────────────────────────────────────────┐"
    echo "      │  ADMIN CENTER CONFIG:                           │"
    echo "      │  Backend type:  Webcam V4l2  (or Webcam PyAV)   │"
    echo "      │  Device index:  0  (or /dev/video0)             │"
    echo "      └─────────────────────────────────────────────────┘"
  else
    echo "      No V4L2 video devices found."
  fi
else
  echo "      v4l2-ctl not installed. Install: sudo apt install v4l-utils"
  # Still check for /dev/video*
  if ls /dev/video* &>/dev/null; then
    echo "      However, /dev/video* devices exist:"
    ls -la /dev/video* 2>/dev/null | sed 's/^/        /'
    CAMERA_FOUND=true
    if [ -z "$CAMERA_TYPE" ]; then CAMERA_TYPE="v4l2"; fi
  fi
fi
echo ""

# --- Summary ---
if [ "$CAMERA_FOUND" = true ]; then
  echo "  ✓ CAMERA DETECTED: $CAMERA_TYPE"
  echo ""
  echo "  TO CONFIGURE:"
  echo "    1. Open http://localhost:8000 in your browser"
  echo "    2. Go to Admin Center (gear icon)"
  echo "    3. Navigate to CONFIGURATION → Camera"
  echo "    4. Set 'Backend type' to: $CAMERA_TYPE"
  echo "    5. Apply the resolution settings shown above"
  echo "    6. Save and restart the app"
else
  echo "  ✗ NO CAMERA DETECTED"
  echo ""
  echo "  Troubleshooting:"
  echo "    • Pi Camera: check ribbon cable, run 'rpicam-hello'"
  echo "    • DSLR: connect via USB, power on, run 'gphoto2 --auto-detect'"
  echo "    • USB webcam: plug in, run 'ls /dev/video*'"
fi

echo ""
echo ""

# ==================================================================
# 2. PRINTER DETECTION
# ==================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PRINTERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PRINTER_FOUND=false

# --- Check CUPS status ---
echo "  [1] Checking CUPS service..."
if systemctl is-active --quiet cups 2>/dev/null; then
  echo "      ✓ CUPS is running."
else
  echo "      ✗ CUPS is not running."
  echo "      Start with:  sudo systemctl enable --now cups"
fi
echo ""

# --- List printers ---
echo "  [2] Listing configured printers..."
if command -v lpstat &>/dev/null; then
  PRINTERS=$(lpstat -p 2>&1 || true)
  if echo "$PRINTERS" | grep -q "printer"; then
    PRINTER_FOUND=true
    echo "$PRINTERS" | sed 's/^/      /'
    echo ""

    # Show default printer
    DEFAULT_PRINTER=$(lpstat -d 2>/dev/null | grep -oP 'destination: \K.*' || true)
    if [ -n "$DEFAULT_PRINTER" ]; then
      echo "      Default printer: $DEFAULT_PRINTER"
    fi

    # List options for each printer
    echo ""
    echo "  [3] Printer options:"
    lpstat -p 2>/dev/null | grep -oP 'printer \K\S+' | while read -r PNAME; do
      echo ""
      echo "      $PNAME:"
      lpoptions -p "$PNAME" -l 2>/dev/null | head -10 | sed 's/^/        /'
      echo "        ... (run: lpoptions -p $PNAME -l  for full list)"
    done
  else
    echo "      No printers configured in CUPS."
    echo "      Connect your printer via USB and add it at: http://localhost:631"
  fi
else
  echo "      lpstat not found. Install: sudo apt install cups cups-client"
fi
echo ""

# --- Check USB for known dye-sub printers ---
echo "  [4] Checking USB for known dye-sub printers..."
if command -v lsusb &>/dev/null; then
  PRINTERS_USB=$(lsusb 2>/dev/null | grep -iE "DNP|Canon.*Selphy|Mitsubishi|Citizen|Kodak|HiTi|Fuji.*ASK" || true)
  if [ -n "$PRINTERS_USB" ]; then
    echo "      ✓ Dye-sub printer detected on USB:"
    echo "$PRINTERS_USB" | sed 's/^/        /'
    if [ "$PRINTER_FOUND" = false ]; then
      echo ""
      echo "      The printer is connected but not configured in CUPS."
      echo "      Add it at: http://localhost:631/admin → Add Printer"
    fi
  else
    echo "      No known dye-sub printers on USB bus."
    echo "      Other USB devices:"
    lsusb 2>/dev/null | head -8 | sed 's/^/        /'
  fi
else
  echo "      lsusb not available."
fi

echo ""
echo ""

# ==================================================================
# 3. SUMMARY
# ==================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Configure the camera in Admin Center:"
echo "     http://localhost:8000 → Admin → CONFIGURATION → Camera"
echo ""
echo "  2. Configure the printer in CUPS:"
echo "     http://localhost:631 → Administration → Add Printer"
echo ""
echo "  3. Set the print command in Admin Center:"
echo "     http://localhost:8000 → Admin → CONFIGURATION → Share"
echo "     Paste:  lp -d PRINTER_NAME {filename}"
echo "     (See printer-setup.md for full options)"
echo ""
echo "  4. Test the camera: tap any action button on the frontpage."
echo "     If you see a live preview, the camera is working."
echo ""
echo "  5. Test printing: capture a photo, then tap Print."
echo ""
echo "  Admin Center: http://localhost:8000"
echo "  CUPS admin:   http://localhost:631"
echo "  Swagger API:  http://localhost:8000/api/doc"
echo ""
