#!/usr/bin/env bash
# ============================================================================
# patch-breathe-button.sh
#
# Finds the installed photobooth-app's index.html and injects one line to
# load the BREATHE ₿ button script. Idempotent — safe to run multiple times.
# ============================================================================
set -euo pipefail

SCRIPT_TAG='<script src="/userdata/breathe-button.js" defer></script>'
MARKER="breathe-button.js"

echo ""
echo "  Patching photobooth-app index.html to include BREATHE ₿ button..."

# ------------------------------------------------------------------
# 1. Find the installed index.html
# ------------------------------------------------------------------
INDEX_HTML=""

# Search pipx venv
PIPX_VENV="$HOME/.local/share/pipx/venvs/photobooth-app"
if [ -d "$PIPX_VENV" ]; then
  INDEX_HTML=$(find "$PIPX_VENV" -name "index.html" -path "*web*" 2>/dev/null | head -1)
fi

# Search site-packages broadly
if [ -z "$INDEX_HTML" ]; then
  INDEX_HTML=$(find "$HOME/.local" /usr/lib/python3* /usr/local/lib/python3* \
    -name "index.html" -path "*photobooth*web*" 2>/dev/null | head -1) || true
fi

if [ -z "$INDEX_HTML" ]; then
  echo ""
  echo "  Could not find photobooth-app's index.html."
  echo "  This is expected if photobooth-app hasn't been installed yet."
  echo ""
  echo "  After installing, re-run this script:"
  echo "    bash scripts/patch-breathe-button.sh"
  echo ""
  echo "  Or find it manually:"
  echo "    find ~/.local -name 'index.html' -path '*photobooth*' 2>/dev/null"
  echo ""
  exit 1
fi

echo "  Found: $INDEX_HTML"

# ------------------------------------------------------------------
# 2. Check if already patched
# ------------------------------------------------------------------
if grep -qF "$MARKER" "$INDEX_HTML"; then
  echo "  Already patched — nothing to do."
  exit 0
fi

# ------------------------------------------------------------------
# 3. Backup + patch
# ------------------------------------------------------------------
BACKUP="${INDEX_HTML}.bak.$(date +%Y%m%d%H%M%S)"
cp "$INDEX_HTML" "$BACKUP"
echo "  Backup: $BACKUP"

sed -i "s|</body>|  ${SCRIPT_TAG}\n</body>|" "$INDEX_HTML"

if grep -qF "$MARKER" "$INDEX_HTML"; then
  echo "  Patch applied."
  echo ""
  echo "  Restart the app to see the BREATHE ₿ button:"
  echo "    systemctl --user restart photobooth-app"
  echo "    (or kill and re-run: cd ~/photobooth-data && photobooth)"
else
  echo "  ERROR: Patch did not apply. Restoring backup."
  cp "$BACKUP" "$INDEX_HTML"
  exit 1
fi
