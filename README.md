# SXSW Vaporwave ₿ Photobooth

A customized fork of [photobooth-app](https://github.com/photobooth-app/photobooth-app) with a vaporwave + Bitcoin visual identity and a **Breathing Session** feature (before-photo → guided breathwork → after-photo).

## This Is the Source Code

This repo contains the **full photobooth-app source** — Python backend, Vue 3 frontend, plugins, everything. It is installed directly from source, not from PyPI. You can modify any file.

## Setup — Step by Step

```bash
# 1. Clone
git clone https://github.com/VataBlaze/sxswphotobooth.git
cd sxswphotobooth

# 2. Run setup (installs from local source, copies theme files)
chmod +x setup.sh
./setup.sh

# 3. Open a new terminal (or: source ~/.bashrc)

# 4. Start the photobooth
cd ~/photobooth-data && photobooth

# 5. Open http://localhost:8000 → gear icon → password 0000
#    Set camera: CONFIGURATION → Camera → select your backend

# 6. (Pi only) Deploy as kiosk:
bash ~/sxswphotobooth/deploy/install-service.sh
sudo reboot
```

## Hardware

- **Raspberry Pi 5** (64-bit Pi OS) or any **Linux laptop/desktop** (Ubuntu, Debian)
- USB webcam, Pi Camera Module, or DSLR (gphoto2)
- Optional: dye-sublimation printer

## Project Structure

```
sxswphotobooth/
├── src/photobooth/           ← Python backend (FastAPI, services, config)
│   ├── plugins/
│   │   ├── breathing_session/ ← Breathing Session plugin (logging)
│   │   ├── commander/         ← Built-in: HTTP hooks
│   │   ├── gpio_lights/       ← Built-in: GPIO control
│   │   ├── wled/              ← Built-in: LED control
│   │   └── ...
│   ├── services/config/groups/
│   │   └── actions.py         ← Action types (Image, Collage, etc.)
│   └── routers/               ← API endpoints
├── src/web/frontend/          ← Compiled Vue 3 SPA
│   └── index.html             ← Patched to load breathe-button.js
├── userdata/                  ← Theme + custom pages (copied to ~/photobooth-data/)
│   ├── private.css            ← Vaporwave ₿ theme
│   ├── breathing.html         ← Breathing Session page
│   ├── breathe-button.js      ← Injects BREATHE button on frontpage
│   └── frames/
│       └── vaporwave-btc-frame.png
├── scripts/
│   ├── diagnose-hardware.sh   ← Camera/printer detection
│   ├── generate-frame.py      ← Generates the frame overlay PNG
│   └── check-install.sh       ← Diagnose setup problems
├── deploy/                    ← systemd + kiosk (Pi only)
├── setup.sh                   ← One-shot setup script
├── printer-setup.md           ← Printer config guide
└── pyproject.toml             ← Package definition + plugin entry-points
```

## Customization

- **Theme**: Edit `userdata/private.css`, re-run `setup.sh` (or copy manually)
- **Actions**: Modify `src/photobooth/services/config/groups/actions.py`
- **Plugins**: Add to `src/photobooth/plugins/`, register in `pyproject.toml`
- **Frontend**: Compiled Vue 3 in `src/web/frontend/` — rebuild from [photobooth-frontend](https://github.com/photobooth-app/photobooth-frontend) for major changes

## Logging

- App logs: `journalctl --user -u photobooth-app -f`
- Breathing session: `tail -f ~/photobooth-data/log/breathing_session.log`
- On-screen: tap "LOG" button in breathing.html (bottom-left corner)

## License

MIT (inherited from upstream). Fonts: SIL Open Font License.
