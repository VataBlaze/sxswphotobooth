# SXSW Vaporwave ₿ Photobooth

A DIY photobooth built on [photobooth-app](https://github.com/photobooth-app/photobooth-app) with a vaporwave + Bitcoin visual identity and a custom **Breathing Session** feature.

## Hardware

Works on any of:
- **Raspberry Pi 5** (64-bit Raspberry Pi OS) — for deployment
- **Any Linux laptop/desktop** (Ubuntu, Debian, etc.) — for development and testing

Plus: touchscreen or monitor, USB webcam or Pi Camera, and optionally a dye-sub printer.

## Architecture

This is a **standalone customization repo**. It does NOT depend on the upstream photobooth-app GitHub repo. The photobooth-app is installed from PyPI as a separate package, and this repo drops theme, plugin, and config files on top of it.

## Complete Setup — Step by Step

```bash
# 1. Clone this repo
git clone https://github.com/VataBlaze/sxswphotobooth.git
cd sxswphotobooth

# 2. Run setup (installs everything, works on laptop or Pi)
chmod +x setup.sh
./setup.sh

# 3. Open a new terminal so the PATH update takes effect
#    (or run: source ~/.bashrc)

# 4. Start the photobooth
cd ~/photobooth-data
photobooth

# 5. Open http://localhost:8000 in your browser
#    You should see the vaporwave-themed frontpage.

# 6. Configure your camera:
#    - Click the gear icon (Admin Center, password: 0000)
#    - Go to CONFIGURATION → Camera
#    - Set Backend type (run the diagnostic for help):
bash ~/sxswphotobooth/scripts/diagnose-hardware.sh

# 7. (Pi only) Deploy as boot service + kiosk:
bash ~/sxswphotobooth/deploy/install-service.sh
sudo reboot
```

## What Each File Does

| File | Purpose |
|---|---|
| `setup.sh` | **Run once.** Installs deps, fonts, photobooth-app, copies all files, patches the BREATHE button in. |
| `userdata/private.css` | Vaporwave ₿ theme |
| `userdata/breathing.html` | Breathing Session page (before-photo → breathwork → after-photo) |
| `userdata/breathe-button.js` | Injects the BREATHE ₿ button on the frontpage |
| `userdata/frames/vaporwave-btc-frame.png` | Neon frame overlay for live preview |
| `plugins/breathing_session/` | Backend plugin with file logging |
| `scripts/patch-breathe-button.sh` | Patches the installed index.html (called by setup.sh) |
| `scripts/diagnose-hardware.sh` | Detects cameras + printers, prints config instructions |
| `scripts/generate-frame.py` | Generates the frame overlay PNG (called by setup.sh) |
| `deploy/` | systemd service + kiosk autostart (Pi deployment only) |
| `printer-setup.md` | Printer configuration guide |

## Logging

Breathing session logs go to `~/photobooth-data/log/breathing_session.log`. The breathing.html page also has an on-screen log panel (tap "LOG" button, bottom-left corner).

## References

- Upstream: <https://github.com/photobooth-app/photobooth-app>
- Docs: <https://photobooth-app.org/>
- Admin Center password: `0000`
- REST API: `http://localhost:8000/api/doc`

## License

MIT (inherited from upstream). Fonts are SIL Open Font License.
