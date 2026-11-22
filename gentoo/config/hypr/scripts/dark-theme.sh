#!/bin/sh
# dark-theme.sh - dark mode for GTK 3, GTK 4 (libadwaita), icons and cursor.
#
# Hyprland runs this script at start (hyprland.lua). install.sh runs it too.
# It writes to gsettings (dconf). GTK programs on Wayland read these values.
# The colors are not here. They are in ~/.config/gtk-3.0/gtk.css and
# ~/.config/gtk-4.0/gtk.css.
#
# If a theme is not installed, the script uses the next one in the list:
#   GTK 3:  adw-gtk3-dark (::guru x11-themes/adw-gtk3), Adwaita-dark, Adwaita
#   icons:  Papirus-Dark (x11-themes/papirus-icon-theme), Adwaita

found() {  # found DIR_NAME FOLDER...
  name=$1
  shift
  for dir in "$@"; do
    [ -d "$dir/$name" ] && return 0
  done
  return 1
}

theme_found() {
  found "$1" "$HOME/.local/share/themes" "$HOME/.themes" /usr/share/themes
}

icons_found() {
  found "$1" "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons
}

gtk_theme=Adwaita
if theme_found adw-gtk3-dark; then
  gtk_theme=adw-gtk3-dark
elif theme_found Adwaita-dark; then
  gtk_theme=Adwaita-dark
fi
# With plain "Adwaita", GTK 3 is dark because gtk-3.0/settings.ini has
# gtk-application-prefer-dark-theme=1.

icon_theme=Adwaita
if icons_found Papirus-Dark; then
  icon_theme=Papirus-Dark
fi

set_key() {
  gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null
}

set_key color-scheme prefer-dark      # libadwaita, GTK 4.20+, Electron, Zen
set_key gtk-theme "$gtk_theme"         # GTK 3
set_key icon-theme "$icon_theme"
set_key cursor-theme phinger-cursors-dark
set_key cursor-size 40
# GNOME 47+ schemas only. Older schemas do not have this key, and the line
# then does nothing. gtk-4.0/gtk.css sets the real accent color (cyan).
set_key accent-color blue

exit 0
