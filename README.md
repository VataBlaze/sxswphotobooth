# SXSW Vaporwave ₿ Photobooth

A DIY photobooth built on [photobooth-app](https://github.com/photobooth-app/photobooth-app) (v8.7.0) with a vaporwave + Bitcoin visual identity and a custom **Breathing Session** feature (before-photo → guided breathwork → after-photo).

## Hardware

- **Raspberry Pi 5** (64-bit Raspberry Pi OS — Bookworm or Trixie)
- Touchscreen monitor (min 1024×600)
- Camera — Pi Camera Module, DSLR (gphoto2), or USB webcam
- Dye-sublimation printer (DNP DS-RX1HS, Canon Selphy, Mitsubishi CP, etc.)

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/VataBlaze/sxswphotobooth.git
cd sxswphotobooth

# 2. Run the setup script (installs deps, fonts, photobooth-app)
chmod +x setup.sh
./setup.sh

# 3. Start the photobooth for first-time configuration
cd ~/photobooth-data
photobooth
# Open http://localhost:8000 → Admin Center → configure your camera

# 4. Set up your printer (see printer-setup.md)

# 5. Deploy as a boot service with kiosk mode
cd /path/to/sxswphotobooth
chmod +x deploy/*.sh
bash deploy/install-service.sh

# 6. Reboot — the photobooth launches automatically
sudo reboot
```

## What's Included

| File / Directory | Purpose |
|---|---|
| `setup.sh` | One-shot system setup for a fresh Pi OS install |
| `userdata/private.css` | Vaporwave ₿ theme (neon gradients, pixel fonts, scanlines) |
| `userdata/breathing.html` | Self-contained Breathing Session page |
| `plugins/breathing_session/` | Server-side plugin for session state tracking |
| `deploy/` | systemd service, kiosk autostart, install script |
| `printer-setup.md` | Printer configuration guide (CUPS + lp commands) |

## Theme

The visual identity fuses **vaporwave** aesthetics (neon pink/cyan/purple, wireframe grids, palm silhouettes, CRT scanlines) with **Bitcoin** motifs (₿ symbol, orange #F7931A, Lightning bolt, "STACK SATS").

Custom fonts (all SIL Open Font License, self-hosted):
- **Press Start 2P** — headings and buttons
- **VT323** — body and status text
- **Monoton** — countdown display
- **Space Mono** — code / secondary text

## Breathing Session

A before/after breathwork experience:

1. Tap **BREATHE ₿** on the main screen
2. A "before" photo is captured automatically
3. A 4-minute guided breathing session plays (4s inhale → 4s hold → 6s exhale → 2s pause)
4. An "after" photo is captured at the end
5. Both photos are displayed side-by-side for review and printing

The session page lives at `http://localhost:8000/userdata/breathing.html` and accepts URL parameters:
- `?duration=300` — session length in seconds (default 240)
- `?pattern=4-4-6-2` — inhale-hold-exhale-pause in seconds
- `?title=BREATHE%20₿` — custom title text

## Configuration

All photobooth-app settings are managed via the **Admin Center** at `http://localhost:8000`. Key areas:

- **Camera**: Admin Center → Configuration → Camera
- **Printer**: Admin Center → Configuration → Share (see [printer-setup.md](printer-setup.md))
- **Theme**: Edit `~/photobooth-data/userdata/private.css`
- **Frame overlay**: Place PNGs in `~/photobooth-data/userdata/frames/`

## References

- Upstream project: <https://github.com/photobooth-app/photobooth-app>
- Documentation: <https://photobooth-app.org/>
- Installation guide: <https://photobooth-app.org/setup/installation/>
- Camera setup: <https://photobooth-app.org/configuration/camera_setup/>
- Theme customization: <https://photobooth-app.org/reference/customizetheme/>
- Plugin reference: <https://photobooth-app.org/reference/plugins/>
- REST API (Swagger): `http://localhost:8000/api/doc`
- Printer examples: <https://photobooth-app.org/extras/printerexample/>

## License

This project is based on [photobooth-app](https://github.com/photobooth-app/photobooth-app), which is released under the **MIT License**. All modifications in this repository are also released under the MIT License.

The fonts used (Press Start 2P, VT323, Monoton, Space Mono) are licensed under the **SIL Open Font License**.
