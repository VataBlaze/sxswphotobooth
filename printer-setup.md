# Printer Setup — Vaporwave ₿ Photobooth

This guide covers configuring a dye-sublimation printer for the photobooth.
The primary example uses a **DNP DS-RX1HS**, with notes for Canon Selphy and
Mitsubishi CP series.

---

## 1. Prerequisites

The `setup.sh` script already installs these, but verify they're present:

```bash
sudo apt -y install cups cups-client printer-driver-gutenprint
```

## 2. Add Your User to the Printer Admin Group

```bash
sudo usermod -aG lpadmin $USER
```

Log out and back in (or reboot) for the group change to take effect.

## 3. Configure the Printer in CUPS

1. Connect your printer via USB.

2. Open the CUPS web interface in a browser:

   ```
   http://localhost:631
   ```

3. Navigate to **Administration → Add Printer**.

4. CUPS should detect the USB printer. Select it and click **Continue**.

5. Give it a name you'll reference later (e.g., `DNP_RX1HS`). Check **Share
   This Printer** if you want network access (not required for local use).

6. Select the appropriate driver:
   - **DNP DS-RX1HS**: Choose the Gutenprint driver (`DNP DS-RX1HS - CUPS+Gutenprint`).
   - **Canon Selphy CP1500**: Use the Gutenprint driver for your model.
   - **Mitsubishi CP-D70DW / CP-D90DW**: Gutenprint or the manufacturer's
     Linux driver if available.

7. Set default media/paper size appropriate for your printer and media.

8. Click **Add Printer** to finish.

## 4. Verify the Printer

### Print a CUPS test page

```bash
lp -d DNP_RX1HS /usr/share/cups/data/testprint
```

### List available options

```bash
lpoptions -p DNP_RX1HS -l
```

This shows all configurable options (PageSize, Resolution, MediaType, etc.).
Note the exact option names and values — you'll need them for the print
command.

## 5. Build the Print Command

The photobooth-app's share/print action runs a shell command with a
`{filename}` placeholder that gets replaced with the path to the image file.

### DNP DS-RX1HS — 4×6 prints

```bash
lp -d DNP_RX1HS -o PageSize=w288h432 -o Resolution=300dpi -o orientation-requested=3 {filename}
```

Key options:
- `-d DNP_RX1HS` — printer name (must match CUPS name exactly)
- `-o PageSize=w288h432` — 4×6 inch media (288×432 points)
- `-o Resolution=300dpi` — print resolution
- `-o orientation-requested=3` — landscape orientation (use `4` for portrait)

### Canon Selphy CP1500 — postcard size

```bash
lp -d Canon_Selphy -o PageSize=Postcard -o Resolution=300dpi {filename}
```

### Mitsubishi CP-D70DW — 4×6

```bash
lp -d Mitsubishi_CPD70 -o PageSize=w288h432 -o Resolution=300dpi -o orientation-requested=3 {filename}
```

> **Tip:** Run `lpoptions -p YOUR_PRINTER -l` to discover the exact option
> names for your model. PageSize values vary between drivers.

## 6. Configure in the Photobooth Admin Center

1. Open the photobooth Admin Center: `http://localhost:8000`

2. Navigate to **CONFIGURATION → share** (or **Share/Print** depending on
   version).

3. Find the **Print Action** or **Share Command** field.

4. Paste your `lp` command with the `{filename}` placeholder:

   ```
   lp -d DNP_RX1HS -o PageSize=w288h432 -o Resolution=300dpi -o orientation-requested=3 {filename}
   ```

5. Save the configuration.

## 7. End-to-End Test

1. Take a photo in the photobooth.
2. From the gallery or review screen, tap the print/share button.
3. Verify the print job appears in CUPS: `lpstat -o`
4. Verify the physical print looks correct (orientation, color, no cropping).

## Troubleshooting

| Problem | Check |
|---------|-------|
| Printer not detected in CUPS | `lsusb` — is the printer listed? Check USB cable. |
| Driver not available | `apt list --installed \| grep gutenprint` — reinstall if missing. |
| Print job stuck/errored | `lpstat -p -l` and check `/var/log/cups/error_log`. |
| Wrong orientation | Change `-o orientation-requested=` between `3` (landscape) and `4` (portrait). |
| Image cropped | Verify PageSize matches your media. Try removing orientation option to let the driver auto-rotate. |
| Colors look wrong | Check MediaType option (`lpoptions -p PRINTER -l`). Dye-sub printers need the correct media type for proper color calibration. |

## References

- Photobooth-app printer docs: <https://photobooth-app.org/extras/printerexample/>
- Photobooth-app share/print config: <https://photobooth-app.org/configuration/share_print/>
- CUPS documentation: <https://www.cups.org/documentation.html>
- Gutenprint supported printers: <https://gimp-print.sourceforge.io/p_Supported_Printers.php>
