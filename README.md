# macosify-ubuntu

Make Ubuntu GNOME look closer to macOS with one script.

This script installs and applies:
- WhiteSur GTK theme
- WhiteSur icon theme
- McMojave cursor theme
- macOS-style wallpaper
- Bottom floating dock/taskbar behavior (Dash to Dock / Ubuntu Dock settings)

It also reuses previously downloaded repositories (no unnecessary recloning).

## What This Script Does

The script (`macosify-ubuntu.sh`) will:

1. Install required GNOME tooling with `apt`
2. Prepare theme repositories under:
   - `~/.cache/macosify-ubuntu/repos`
3. Install themes/cursors from upstream repos
4. Apply theme, icon, and cursor via `gsettings`
5. Set a macOS-style wallpaper (if found)
6. Configure dock/taskbar to macOS-like behavior:
   - bottom position
   - non-fixed dock (`dock-fixed=false`) to avoid fullscreen bottom gap
   - autohide behavior

## Requirements

- Ubuntu or Debian-based distro (`apt` required)
- GNOME desktop
- Internet connection
- A user account with `sudo` privileges
- Run in a graphical GNOME session (not pure TTY)

## Usage

From your home directory:

```bash
chmod +x ./Project/macosify-ubuntu/macosify-ubuntu.sh
./Project/macosify-ubuntu/macosify-ubuntu.sh
```

After completion, log out and log back in so GNOME Shell changes apply cleanly.

## Re-running the Script

Safe to rerun.

Repository handling is idempotent:
- If repo already exists and origin matches, it fetches and pulls updates
- If repo directory is invalid or mismatched, it reclones automatically

## Wallpaper Behavior

The script tries to set wallpaper from:
1. `WhiteSur-wallpapers` repository
2. Fallback wallpaper assets in `WhiteSur-gtk-theme`

The chosen wallpaper is copied to:
- `~/Pictures/macosify-ubuntu/`

Then applied to both:
- `org.gnome.desktop.background picture-uri`
- `org.gnome.desktop.background picture-uri-dark`

## Troubleshooting

### Fullscreen apps still show dock at bottom

Run:

```bash
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
gsettings set org.gnome.shell.extensions.dash-to-dock require-pressure-to-show false
```

Then log out/in.

### Dock extension not found

Install and enable Dash to Dock from Extension Manager, then rerun the script.

### Theme/icon not detected

Rerun the script once and check warnings in output. Some GNOME sessions need relogin before values are visible.

## Notes

- This project automates setup; upstream themes/icons/wallpapers remain under their original licenses.
- If you publish this repository, include your own project license (MIT is a common choice for scripts like this).

## Upstream Projects

- https://github.com/vinceliuice/WhiteSur-gtk-theme
- https://github.com/vinceliuice/WhiteSur-icon-theme
- https://github.com/vinceliuice/McMojave-cursors
- https://github.com/vinceliuice/WhiteSur-wallpapers
