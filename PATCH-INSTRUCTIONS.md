# V5 Patch — Apply Instructions
#
# This patch fixes the repo so it builds and runs from YOUR source code,
# not from PyPI.
#
# ============================================================
# FILES TO DELETE (redundant / broken)
# ============================================================
#
# 1. DELETE the entire double-nested plugin directory:
#      src/photobooth/plugins/breathing_session/breathing_session/
#    This is a duplicate that will confuse Python imports.
#    The correct files are one level up at:
#      src/photobooth/plugins/breathing_session/breathing_session.py
#      src/photobooth/plugins/breathing_session/config.py
#
# 2. DELETE the obsolete patch script:
#      scripts/patch-breathe-button.sh
#    No longer needed — index.html is patched directly in source.
#
# ============================================================
# FILES TO REPLACE (exist but need updating)
# ============================================================
#
# 3. REPLACE: setup.sh
#    Old: installs from PyPI, ignoring your source code
#    New: installs from local repo via `pipx install .`
#
# 4. REPLACE: src/photobooth/plugins/breathing_session/__init__.py
# 5. REPLACE: src/photobooth/plugins/breathing_session/breathing_session.py
#    Old: used wrong base class (BaseModel), wrong imports
#    New: uses BasePlugin[BreathingSessionConfig], proper hookimpls
#
# 6. REPLACE: src/photobooth/plugins/breathing_session/config.py
#    Old: used pydantic BaseModel (not visible in Admin Center)
#    New: uses BaseConfig with JSON persistence
#
# 7. REPLACE: pyproject.toml
#    Change: adds breathing_session to [project.entry-points.photobooth11]
#    Change: updates project URLs to VataBlaze repo
#
# 8. REPLACE: src/web/frontend/index.html
#    Change: adds <script src="/userdata/breathe-button.js" defer>
#
# 9. REPLACE: README.md
#    Old: described "standalone customization repo" (wrong)
#    New: describes source-owned fork (correct)
#
# 10. REPLACE: deploy/* (minor — already correct, included for completeness)
# 11. REPLACE: scripts/diagnose-hardware.sh (laptop+Pi support)
# 12. REPLACE: printer-setup.md (unchanged, included for completeness)
#
# ============================================================
# FILES TO CREATE (don't exist in repo yet)
# ============================================================
#
# 13. CREATE: userdata/private.css          — the vaporwave ₿ theme
# 14. CREATE: userdata/breathing.html       — the breathing session page
# 15. CREATE: userdata/breathe-button.js    — button injector script
# 16. CREATE: userdata/frames/vaporwave-btc-frame.png — frame overlay
# 17. CREATE: scripts/check-install.sh      — installation diagnostic
# 18. CREATE: scripts/generate-frame.py     — frame overlay generator
#
# ============================================================
# TERMINAL COMMANDS (run in order)
# ============================================================
#
# cd ~/sxswphotobooth
#
# # Delete the broken nested plugin:
# rm -rf src/photobooth/plugins/breathing_session/breathing_session/
#
# # Delete the obsolete patch script:
# rm -f scripts/patch-breathe-button.sh
#
# # Extract the v5 patch zip and copy all files into place:
# # (the zip mirrors the repo directory structure)
# unzip -o sxsw-photobooth-v5-patch.zip -d ~/sxswphotobooth/
#
# # Verify:
# ls userdata/private.css userdata/breathing.html userdata/breathe-button.js
#
# # Re-run setup:
# chmod +x setup.sh
# ./setup.sh
#
# # Start:
# cd ~/photobooth-data && photobooth
