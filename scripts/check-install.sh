#!/usr/bin/env bash
# ============================================================================
# check-install.sh — Diagnose why the theme / BREATHE session aren't loading
# Run from anywhere:  bash ~/sxswphotobooth/scripts/check-install.sh
# ============================================================================

DATA_DIR="$HOME/photobooth-data"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   INSTALLATION DIAGNOSTIC                        ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# 1. Check if photobooth-data exists and what's in it
echo "━━━ DATA DIRECTORY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -d "$DATA_DIR" ]; then
  echo "  ✓ $DATA_DIR exists"
  echo ""
  echo "  Contents:"
  find "$DATA_DIR" -maxdepth 3 -type f 2>/dev/null | sort | sed 's/^/    /'
  echo ""
else
  echo "  ✗ $DATA_DIR DOES NOT EXIST"
  echo "    This is the problem. Run setup.sh first."
  echo ""
fi

# 2. Check critical files
echo "━━━ CRITICAL FILES ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
FILES_TO_CHECK=(
  "$DATA_DIR/userdata/private.css"
  "$DATA_DIR/userdata/breathing.html"
  "$DATA_DIR/userdata/breathe-button.js"
  "$DATA_DIR/plugins/breathing_session/breathing_session.py"
  "$DATA_DIR/plugins/breathing_session/config.py"
  "$DATA_DIR/userdata/frames/vaporwave-btc-frame.png"
)
ALL_OK=true
for f in "${FILES_TO_CHECK[@]}"; do
  if [ -f "$f" ]; then
    SIZE=$(stat --format=%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo "?")
    echo "  ✓ $(basename "$f")  ($SIZE bytes)"
  else
    echo "  ✗ MISSING: $f"
    ALL_OK=false
  fi
done
echo ""

# 3. Check if private.css has actual content (not empty)
if [ -f "$DATA_DIR/userdata/private.css" ]; then
  LINES=$(wc -l < "$DATA_DIR/userdata/private.css")
  if [ "$LINES" -gt 10 ]; then
    echo "  ✓ private.css has $LINES lines (looks good)"
  else
    echo "  ✗ private.css only has $LINES lines — may be empty/wrong"
  fi
  # Check for our vaporwave signature
  if grep -q "1A0A2E" "$DATA_DIR/userdata/private.css"; then
    echo "  ✓ private.css contains vaporwave theme colors"
  else
    echo "  ✗ private.css does NOT contain vaporwave colors — wrong file?"
  fi
fi
echo ""

# 4. Check if photobooth command exists
echo "━━━ PHOTOBOOTH-APP ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v photobooth &>/dev/null; then
  echo "  ✓ photobooth command found: $(which photobooth)"
elif [ -f "$HOME/.local/bin/photobooth" ]; then
  echo "  ✓ photobooth at ~/.local/bin/photobooth (but not in current PATH)"
  echo "    Fix: run 'source ~/.bashrc' or open a new terminal"
else
  echo "  ✗ photobooth command not found"
  echo "    Run:  pipx install photobooth-app --pip-args='--prefer-binary'"
fi
echo ""

# 5. Check if a photobooth process is running and WHERE from
echo "━━━ RUNNING PROCESS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PB_PIDS=$(pgrep -f "photobooth" 2>/dev/null || true)
if [ -n "$PB_PIDS" ]; then
  echo "  Photobooth is running (PID: $PB_PIDS)"
  echo ""
  echo "  Process details:"
  ps -p $PB_PIDS -o pid,cwd,command --no-headers 2>/dev/null | sed 's/^/    /'
  echo ""
  # Check the working directory of the process
  for pid in $PB_PIDS; do
    CWD=$(readlink /proc/$pid/cwd 2>/dev/null || echo "unknown")
    echo "  PID $pid working directory: $CWD"
    if [ "$CWD" = "$DATA_DIR" ]; then
      echo "  ✓ Running from correct directory ($DATA_DIR)"
    else
      echo "  ✗ RUNNING FROM WRONG DIRECTORY!"
      echo "    The app is running from: $CWD"
      echo "    It should run from:      $DATA_DIR"
      echo ""
      echo "    THIS IS LIKELY THE PROBLEM."
      echo "    The photobooth-app uses the current working directory"
      echo "    as its data folder. If you started it from a different"
      echo "    directory, it won't find private.css or the plugins."
      echo ""
      echo "    Fix:"
      echo "      1. Stop the current process: kill $pid"
      echo "      2. Restart from the right directory:"
      echo "         cd ~/photobooth-data && photobooth"
    fi
  done
else
  echo "  Photobooth is NOT currently running."
  echo "  Start it with:  cd ~/photobooth-data && photobooth"
fi
echo ""

# 6. Check if the app is responding at localhost:8000
echo "━━━ WEB SERVER ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null | grep -q "200"; then
  echo "  ✓ http://localhost:8000/ is responding"

  # Check if private.css is being served
  CSS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/private.css 2>/dev/null)
  if [ "$CSS_STATUS" = "200" ]; then
    CSS_SIZE=$(curl -s http://localhost:8000/private.css 2>/dev/null | wc -c)
    echo "  ✓ /private.css is being served ($CSS_SIZE bytes)"
    if [ "$CSS_SIZE" -gt 100 ]; then
      echo "  ✓ CSS has content (theme should be visible)"
    else
      echo "  ✗ CSS is nearly empty — theme won't show"
    fi
  else
    echo "  ✗ /private.css returned HTTP $CSS_STATUS"
    echo "    The app is not finding the CSS file."
  fi

  # Check if breathing.html is accessible
  BREATH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/userdata/breathing.html 2>/dev/null)
  if [ "$BREATH_STATUS" = "200" ]; then
    echo "  ✓ /userdata/breathing.html is accessible"
  else
    echo "  ✗ /userdata/breathing.html returned HTTP $BREATH_STATUS"
  fi
else
  echo "  ✗ http://localhost:8000/ is not responding"
  echo "    The photobooth is not running."
fi

echo ""
echo "━━━ SUMMARY ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ "$ALL_OK" = true ]; then
  echo "  All files are in place."
  echo ""
  echo "  If the theme still isn't showing, the most common cause is"
  echo "  starting the app from the WRONG DIRECTORY."
  echo ""
  echo "  The photobooth-app uses the current working directory (CWD)"
  echo "  as its data folder. You MUST start it like this:"
  echo ""
  echo "    cd ~/photobooth-data && photobooth"
  echo ""
  echo "  NOT like this:"
  echo "    cd ~/sxswphotobooth && photobooth    ← WRONG"
  echo "    photobooth                           ← WRONG (unless CWD is photobooth-data)"
else
  echo "  Some files are missing. Re-run setup.sh:"
  echo "    cd ~/sxswphotobooth && ./setup.sh"
fi
echo ""
