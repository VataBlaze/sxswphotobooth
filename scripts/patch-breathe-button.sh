#!/usr/bin/env bash
# ============================================================================
# patch-breathe-button.sh
#
# Finds the installed photobooth-app's index.html (inside the pipx venv) and
# injects a <script> tag that loads /userdata/breathe-button.js.
#
# This is idempotent — running it twice will not duplicate the tag.
#
# Usage:  bash scripts/patch-breathe-button.sh
# ============================================================================
set -euo pipefail

SCRIPT_TAG='<script src="/userdata/breathe-button.js" defer></script>'
MARKER="breathe-button.js"

echo ""
echo "  Patching photobooth-app index.html to include BREATHE ₿ button..."
echo ""

# ------------------------------------------------------------------
# 1. Locate the installed index.html
# ------------------------------------------------------------------
INDEX_HTML=""

# Method A: Search the pipx venv
PIPX_VENV="$HOME/.local/share/pipx/venvs/photobooth-app"
if [ -d "$PIPX_VENV" ]; then
  FOUND=$(find "$PIPX_VENV" -name "index.html" -path "*/web_spa/*" 2>/dev/null | head -1)
  if [ -n "$FOUND" ]; then
    INDEX_HTML="$FOUND"
  fi
fi

# Method B: Search site-packages broadly
if [ -z "$INDEX_HTML" ]; then
  FOUND=$(find "$HOME/.local" /usr/lib/python3*/site-packages /usr/local/lib/python3*/site-packages \
    -name "index.html" -path "*/photobooth*web*" 2>/dev/null | head -1)
  if [ -n "$FOUND" ]; then
    INDEX_HTML="$FOUND"
  fi
fi

# Method C: Ask Python directly
if [ -z "$INDEX_HTML" ]; then
  FOUND=$(python3 -c "
import importlib.util, os
spec = importlib.util.find_spec('photobooth')
if spec and spec.submodule_search_locations:
    for loc in spec.submodule_search_locations:
        for root, dirs, files in os.walk(loc):
            if 'index.html' in files and 'web' in root:
                print(os.path.join(root, 'index.html'))
                break
" 2>/dev/null | head -1)
  if [ -n "$FOUND" ]; then
    INDEX_HTML="$FOUND"
  fi
fi

if [ -z "$INDEX_HTML" ]; then
  echo "  ERROR: Could not find the photobooth-app index.html."
  echo "  Searched:"
  echo "    - $PIPX_VENV"
  echo "    - ~/.local/lib/python3*/site-packages/photobooth/"
  echo "    - Python importlib"
  echo ""
  echo "  Try running:  find / -name 'index.html' -path '*photobooth*' 2>/dev/null"
  echo "  Then edit the file manually, adding before </body>:"
  echo "    $SCRIPT_TAG"
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
# 3. Backup the original
# ------------------------------------------------------------------
BACKUP="${INDEX_HTML}.bak.$(date +%Y%m%d%H%M%S)"
cp "$INDEX_HTML" "$BACKUP"
echo "  Backup created: $BACKUP"

# ------------------------------------------------------------------
# 4. Inject the script tag before </body>
# ------------------------------------------------------------------
# Use sed to insert our script tag on the line before </body>
sed -i "s|</body>|  ${SCRIPT_TAG}\n</body>|" "$INDEX_HTML"

# Verify
if grep -qF "$MARKER" "$INDEX_HTML"; then
  echo "  Patch applied successfully."
  echo ""
  echo "  The BREATHE ₿ button will appear on the photobooth frontpage"
  echo "  after restarting the app or refreshing the browser."
  echo ""
  echo "  Restart:  systemctl --user restart photobooth-app"
else
  echo "  ERROR: Patch did not apply. Restoring backup."
  cp "$BACKUP" "$INDEX_HTML"
  exit 1
fi
