#!/usr/bin/env bash
# ============================================================================
# diagnose-hardware.sh
#
# Detects cameras and printers on the current system (laptop or Pi) and
# prints the exact configuration steps for the photobooth-app Admin Center.
# ============================================================================
set -uo pipefail

# Detect platform
IS_PI=false
if grep -qi "raspberry" /proc/device-tree/model 2>/dev/null || \
   grep -qi "raspberry" /proc/cpuinfo 2>/dev/null; then
  IS_PI=true
fi

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   HARDWARE DIAGNOSTICS                           ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ "$IS_PI" = true ]; then
  echo "  Platform: Raspberry Pi"
else
  echo "  Platform: Linux laptop/desktop"
fi
echo ""

# ==================================================================
# CAMERAS
# ==================================================================
echo "━━━ CAMERAS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CAMERA_FOUND=false
RECOMMENDED_BACKEND=""

# --- Pi Camera Module (Pi only) ---
if [ "$IS_PI" = true ]; then
  echo "  [1] Raspberry Pi Camera Module..."
  if command -v rpicam-hello &>/dev/null; then
    PICAM_LIST=$(rpicam-hello --list-cameras 2>&1 || true)
    if echo "$PICAM_LIST" | grep -q "Available cameras"; then
      CAMERA_FOUND=true
      RECOMMENDED_BACKEND="Picamera2"
      echo "      ✓ Pi Camera detected!"
      echo "$PICAM_LIST" | head -10 | sed 's/^/        /'
      echo ""
      echo "      Admin Center settings:"
      echo "        Backend type:           Picamera2"
      echo "        Camera num:             0"
      echo "        Capture Resolution:     4608 × 2592  (Camera Module 3)"
      echo "        Preview Resolution:     2304 × 1296"
      echo "        Liveview Resolution:    1152 × 648"
    else
      echo "      rpicam-hello exists but no camera found. Check ribbon cable."
    fi
  else
    echo "      rpicam-hello not found. If using Pi Camera, install libcamera."
  fi
  echo ""
fi

# --- USB Webcam (V4L2 — works on both laptop and Pi) ---
echo "  [2] USB Webcam (V4L2)..."
if ls /dev/video* &>/dev/null 2>&1; then
  CAMERA_FOUND=true
  if [ -z "$RECOMMENDED_BACKEND" ]; then
    RECOMMENDED_BACKEND="Webcam V4l2"
  fi
  echo "      ✓ Video devices found:"
  ls -1 /dev/video* 2>/dev/null | sed 's/^/        /'
  echo ""
  if command -v v4l2-ctl &>/dev/null; then
    echo "      Device details:"
    v4l2-ctl --list-devices 2>&1 | head -15 | sed 's/^/        /'
  fi
  echo ""
  echo "      Admin Center settings:"
  echo "        Backend type:    Webcam V4l2  (or Webcam PyAV)"
  echo "        Device index:    0"
else
  echo "      No /dev/video* devices found."
  echo "      Plug in a USB webcam, or if using a laptop's built-in camera,"
  echo "      check that it's not disabled in BIOS/firmware settings."
fi
echo ""

# --- DSLR (gphoto2) ---
echo "  [3] DSLR (gphoto2)..."
if command -v gphoto2 &>/dev/null; then
  GPHOTO_DETECT=$(gphoto2 --auto-detect 2>&1 || true)
  GPHOTO_CAMERAS=$(echo "$GPHOTO_DETECT" | tail -n +3 | grep -v "^$" || true)
  if [ -n "$GPHOTO_CAMERAS" ]; then
    CAMERA_FOUND=true
    if [ -z "$RECOMMENDED_BACKEND" ]; then
      RECOMMENDED_BACKEND="Gphoto2"
    fi
    echo "      ✓ DSLR detected:"
    echo "$GPHOTO_CAMERAS" | sed 's/^/        /'
    echo ""
    echo "      Admin Center settings:"
    echo "        Backend type:    Gphoto2"
    echo ""
    echo "      IMPORTANT: Kill gphoto2 processes that lock the camera:"
    echo "        pkill -f gvfs-gphoto2-volume-monitor"
  else
    echo "      No DSLR found. Connect via USB and power on."
  fi
else
  echo "      gphoto2 not installed."
  echo "      Install:  sudo apt install gphoto2 libgphoto2-dev"
fi
echo ""

# --- Summary ---
echo "━━━ CAMERA SUMMARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$CAMERA_FOUND" = true ]; then
  echo ""
  echo "  ✓ Camera detected.  Recommended backend: $RECOMMENDED_BACKEND"
  echo ""
  echo "  Configure it:"
  echo "    1. Open http://localhost:8000"
  echo "    2. Click the gear icon (Admin Center, password: 0000)"
  echo "    3. Go to CONFIGURATION → Camera"
  echo "    4. Set Backend type to:  $RECOMMENDED_BACKEND"
  echo "    5. Save → Restart the app"
else
  echo ""
  echo "  ✗ No camera detected."
  echo ""
  echo "  On a laptop: check that your webcam isn't disabled or in use"
  echo "               by another app (Zoom, Teams, etc.)."
  echo "  On Pi: check the ribbon cable or plug in a USB webcam."
fi
echo ""

# ==================================================================
# PRINTERS
# ==================================================================
echo "━━━ PRINTERS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if systemctl is-active --quiet cups 2>/dev/null; then
  echo "  ✓ CUPS is running."
else
  echo "  ✗ CUPS is not running.  Start:  sudo systemctl enable --now cups"
fi

if command -v lpstat &>/dev/null; then
  PRINTERS=$(lpstat -p 2>&1 || true)
  if echo "$PRINTERS" | grep -q "printer"; then
    echo ""
    echo "  Configured printers:"
    echo "$PRINTERS" | sed 's/^/    /'
    echo ""
    echo "  Configure in Admin Center → CONFIGURATION → Share → Print Command:"
    echo "    lp -d PRINTER_NAME {filename}"
    echo ""
    echo "  (See printer-setup.md for full options per printer model)"
  else
    echo "  No printers configured. Add one at: http://localhost:631"
  fi
fi

# USB dye-sub check
if command -v lsusb &>/dev/null; then
  DYE_SUB=$(lsusb 2>/dev/null | grep -iE "DNP|Canon.*Selphy|Mitsubishi|Citizen|HiTi" || true)
  if [ -n "$DYE_SUB" ]; then
    echo ""
    echo "  Dye-sub printer on USB:"
    echo "$DYE_SUB" | sed 's/^/    /'
  fi
fi

echo ""
echo "━━━ WHAT TO DO NEXT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Start photobooth:  cd ~/photobooth-data && photobooth"
echo "  2. Open browser:      http://localhost:8000"
echo "  3. Admin Center:      gear icon (password: 0000)"
echo "  4. Set camera:        CONFIGURATION → Camera"
echo "  5. Set printer:       CONFIGURATION → Share"
echo "  6. Swagger API:       http://localhost:8000/api/doc"
echo ""
