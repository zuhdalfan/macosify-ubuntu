#!/usr/bin/env bash
set -euo pipefail

log() { printf "\n[+] %s\n" "$*"; }
warn() { printf "\n[!] %s\n" "$*"; }

if [[ "${EUID}" -eq 0 ]]; then
  warn "Run this script as your normal user, not root."
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  warn "This script is for Ubuntu/Debian (apt-based) systems."
  exit 1
fi

log "Installing required packages"
sudo apt update
sudo apt install -y \
  git \
  curl \
  gnome-tweaks \
  gnome-shell-extensions \
  gnome-shell-extension-manager

log "Installing optional dock extension package (if available)"
if apt-cache show gnome-shell-extension-dash-to-dock >/dev/null 2>&1; then
  sudo apt install -y gnome-shell-extension-dash-to-dock
elif apt-cache show gnome-shell-extension-ubuntu-dock >/dev/null 2>&1; then
  sudo apt install -y gnome-shell-extension-ubuntu-dock
else
  warn "No apt dock extension package found. Will try existing GNOME extension."
fi

WORKDIR="$HOME/.cache/macosify-ubuntu/repos"
mkdir -p "$WORKDIR"

ensure_repo() {
  local repo_url="$1"
  local repo_dir="$2"

  if [[ -d "$repo_dir/.git" ]]; then
    local current_url=""
    current_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

    if [[ "$current_url" == "$repo_url" ]]; then
      log "Repository exists, updating $(basename "$repo_dir")"
      git -C "$repo_dir" fetch --all --prune || true
      git -C "$repo_dir" pull --ff-only || true
      return
    fi

    warn "Repository origin mismatch in $repo_dir, recloning"
    rm -rf "$repo_dir"
  elif [[ -d "$repo_dir" ]]; then
    warn "$repo_dir exists but is not a git repository, recloning"
    rm -rf "$repo_dir"
  fi

  log "Cloning $(basename "$repo_dir")"
  git clone --depth=1 "$repo_url" "$repo_dir"
}

log "Preparing theme repositories"
ensure_repo https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$WORKDIR/WhiteSur-gtk-theme"
ensure_repo https://github.com/vinceliuice/WhiteSur-icon-theme.git "$WORKDIR/WhiteSur-icon-theme"
ensure_repo https://github.com/vinceliuice/McMojave-cursors.git "$WORKDIR/McMojave-cursors"
if ! ensure_repo https://github.com/vinceliuice/WhiteSur-wallpapers.git "$WORKDIR/WhiteSur-wallpapers"; then
  warn "Could not prepare WhiteSur wallpapers repository."
fi

log "Installing WhiteSur GTK theme"
(
  cd "$WORKDIR/WhiteSur-gtk-theme"
  ./install.sh
)

log "Installing WhiteSur icon theme"
(
  cd "$WORKDIR/WhiteSur-icon-theme"
  ./install.sh
)

log "Installing McMojave cursors"
(
  cd "$WORKDIR/McMojave-cursors"
  ./install.sh
)

pick_first_match() {
  local base1="$1"
  local base2="$2"
  local pattern="$3"

  local found=""
  if [[ -d "$base1" ]]; then
    found="$(find "$base1" -maxdepth 1 -mindepth 1 -type d -name "$pattern" | sort | head -n1 || true)"
  fi
  if [[ -z "$found" && -d "$base2" ]]; then
    found="$(find "$base2" -maxdepth 1 -mindepth 1 -type d -name "$pattern" | sort | head -n1 || true)"
  fi
  if [[ -n "$found" ]]; then
    basename "$found"
  fi
}

GTK_THEME="$(pick_first_match "$HOME/.themes" "/usr/share/themes" "WhiteSur*")"
ICON_THEME="$(pick_first_match "$HOME/.icons" "/usr/share/icons" "WhiteSur*")"
CURSOR_THEME="$(pick_first_match "$HOME/.icons" "/usr/share/icons" "McMojave*")"

log "Applying GNOME interface themes"
if [[ -n "${GTK_THEME}" ]]; then
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
else
  warn "Could not auto-detect WhiteSur GTK theme."
fi

if [[ -n "${ICON_THEME}" ]]; then
  gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
else
  warn "Could not auto-detect WhiteSur icon theme."
fi

if [[ -n "${CURSOR_THEME}" ]]; then
  gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
else
  warn "Could not auto-detect McMojave cursor theme."
fi

log "Enabling User Themes extension (for shell theme)"
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com || true
if [[ -n "${GTK_THEME}" ]]; then
  gsettings set org.gnome.shell.extensions.user-theme name "$GTK_THEME" || true
fi

log "Setting macOS-style wallpaper"
WALLPAPER_SOURCE=""
if [[ -d "$WORKDIR/WhiteSur-wallpapers" ]]; then
  WALLPAPER_SOURCE="$(find "$WORKDIR/WhiteSur-wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort | head -n1 || true)"
fi

if [[ -z "$WALLPAPER_SOURCE" ]]; then
  WALLPAPER_SOURCE="$(find "$WORKDIR/WhiteSur-gtk-theme" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -ipath "*wallpaper*" | sort | head -n1 || true)"
fi

if [[ -n "$WALLPAPER_SOURCE" ]]; then
  WALLPAPER_DIR="$HOME/Pictures/macosify-ubuntu"
  mkdir -p "$WALLPAPER_DIR"
  WALLPAPER_DEST="$WALLPAPER_DIR/macosify-wallpaper.${WALLPAPER_SOURCE##*.}"
  cp "$WALLPAPER_SOURCE" "$WALLPAPER_DEST"

  WALLPAPER_URI="file://$WALLPAPER_DEST"
  gsettings set org.gnome.desktop.background picture-uri "$WALLPAPER_URI" || true
  gsettings set org.gnome.desktop.background picture-uri-dark "$WALLPAPER_URI" || true
  gsettings set org.gnome.desktop.background picture-options 'zoom' || true
else
  warn "Could not find a wallpaper image to apply automatically."
fi

log "Configuring dock/taskbar to macOS-like style"
DOCK_EXTENSION=""
if gnome-extensions list | grep -q '^dash-to-dock@micxgx.gmail.com$'; then
  DOCK_EXTENSION="dash-to-dock@micxgx.gmail.com"
elif gnome-extensions list | grep -q '^ubuntu-dock@ubuntu.com$'; then
  DOCK_EXTENSION="ubuntu-dock@ubuntu.com"
fi

if [[ -n "$DOCK_EXTENSION" ]]; then
  gnome-extensions enable "$DOCK_EXTENSION" || true
else
  warn "Dock extension not found. Install Dash to Dock via Extension Manager, then rerun."
fi

gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM' || true
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false || true
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false || true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true || true
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48 || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false || true
gsettings set org.gnome.shell.extensions.dash-to-dock require-pressure-to-show false || true
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' || true
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.20 || true

log "Done"
printf "\nLog out and back in to fully apply shell and dock changes.\n"
