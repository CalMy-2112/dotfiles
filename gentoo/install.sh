#!/bin/sh
# install.sh - link the Gentoo (omen) configs of this repository into ~/.config.
#
#   sh gentoo/install.sh -n    show what the script will do. Change nothing.
#   sh gentoo/install.sh       do it.
#
# Each file in gentoo/config/ gets a link at the same place in ~/.config/.
# Example: gentoo/config/waybar/style.css -> ~/.config/waybar/style.css
# The script also links:
#   wallpapers/hyprland-girl.jpg -> ~/.config/hypr/wallpapers/hyprland-girl.jpg
#   bin/nightlight               -> ~/.local/bin/nightlight
# It sets the btop theme in ~/.config/btop/btop.conf (no link, btop writes
# that file).
#
# The script moves old files to ~/.dots-backup/<date>/ before it makes a
# link. It does not delete files. You can run it again. It skips the links
# that are already correct.
set -eu

dry=0
force=0
for arg in "$@"; do
  case $arg in
    -n) dry=1 ;;
    -f) force=1 ;;
    *) echo "usage: sh gentoo/install.sh [-n] [-f]" >&2; exit 2 ;;
  esac
done

repo=$(cd "$(dirname "$0")/.." && pwd -P)
src="$repo/gentoo/config"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
backup="$HOME/.dots-backup/$(date +%Y%m%d-%H%M%S)"

# The Guix laptops link ~/.config/hypr and others to the top folders of
# this repository. On those laptops this script could move repository files.
# So it runs only on Gentoo, unless you give -f.
if [ ! -e /etc/gentoo-release ] && [ $force = 0 ]; then
  echo "This is not Gentoo (no /etc/gentoo-release). Stop." >&2
  echo "Use -f to continue on a different system." >&2
  exit 1
fi

run() {
  if [ $dry = 1 ]; then
    echo "  would run: $*"
  else
    "$@"
  fi
}

# link SOURCE TARGET
link() {
  s=$1
  t=$2
  if [ -L "$t" ] && [ "$(readlink "$t")" = "$s" ]; then
    return 0
  fi
  # Do not move a file that is inside this repository (a folder link).
  parent=$(cd "$(dirname "$t")" 2>/dev/null && pwd -P || true)
  case "$parent/" in
    "$repo"/*)
      echo "skip:   $t (its folder is a link into the repository)"
      return 0 ;;
  esac
  if [ -e "$t" ] || [ -L "$t" ]; then
    rel=${t#"$HOME"/}
    run mkdir -p "$(dirname "$backup/$rel")"
    run mv "$t" "$backup/$rel"
    echo "backup: ~/$rel -> $backup/$rel"
  fi
  run mkdir -p "$(dirname "$t")"
  run ln -s "$s" "$t"
  echo "link:   ${t#"$HOME"/} -> ${s#"$repo"/}"
}

echo "Repository: $repo"
[ $dry = 1 ] && echo "Dry run (-n): no changes."

find "$src" -type f -print | sort | while IFS= read -r f; do
  link "$f" "$cfg/${f#"$src"/}"
done

link "$repo/wallpapers/hyprland-girl.jpg" "$cfg/hypr/wallpapers/hyprland-girl.jpg"
link "$repo/bin/nightlight" "$HOME/.local/bin/nightlight"

# btop writes btop.conf when it stops, so the file is not a link.
# Close btop before you run this script, or btop writes the old values back.
btop_conf="$cfg/btop/btop.conf"
set_btop() {
  if [ -f "$btop_conf" ] && grep -q "^$1 *=" "$btop_conf"; then
    run sed -i "s|^$1 *=.*|$1 = $2|" "$btop_conf"
  elif [ $dry = 1 ]; then
    echo "  would add: $1 = $2 to $btop_conf"
  else
    mkdir -p "$(dirname "$btop_conf")"
    printf '%s = %s\n' "$1" "$2" >> "$btop_conf"
  fi
  echo "btop:   $1 = $2"
}
set_btop color_theme '"night-train"'
set_btop theme_background False

# gsettings needs the D-Bus session of your desktop. From a text console
# there is none. Then Hyprland runs the script at the next start.
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v gsettings >/dev/null; then
  run sh "$src/hypr/scripts/dark-theme.sh"
  echo "gtk:    dark theme set with gsettings"
else
  echo "gtk:    no D-Bus session. Hyprland sets the dark theme at the next start."
fi

if [ -d "$backup" ]; then
  echo "Old files are in $backup"
fi
echo "Done. Log out of Hyprland and log in again to see all changes."
