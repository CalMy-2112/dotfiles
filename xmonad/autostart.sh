#!/usr/bin/env bash
# ~/.config/xmonad/autostart.sh — run once at xmonad login (spawnOnce).
# Each line is guarded so a missing program doesn't break the rest.

run() { command -v "$1" >/dev/null 2>&1 && "$@" & }

# ~/.config/xmonad is a symlink into the dotfiles repo; find the repo root
dots="$(dirname "$(dirname "$(readlink -f "$0")")")"

# Normal mouse cursor instead of the X
xsetroot -cursor_name left_ptr

# Wallpaper from the repo's wallpapers/ folder
wall="$dots/wallpapers/night-train.jpg"
if [ -f "$wall" ]; then
  feh --no-fehbg --bg-fill "$wall"
else
  xsetroot -solid '#0b0b0b'
fi

# Compositor (stops video tearing). Remove if it causes issues.
run picom --backend glx --vsync

# Notifications
run dunst

# Password prompts for apps that need root (software updater, etc.)
[ -x /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 ] &&
  /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 &

# Lock screen on suspend / Super+Ctrl+l, auto-lock after 10 min idle
xset s 600 600
run xss-lock --transfer-sleep-lock -- i3lock -n -c 0b0b0b

# System tray: sits in the right 10% of the top bar (xmobar takes the left 90%)
run trayer --edge top --align right --widthtype percent --width 10 \
  --height 24 --SetDockType true --SetPartialStrut true --expand true \
  --transparent true --alpha 0 --tint 0x0b0b0b --monitor primary

# Tray applets (give trayer a moment to start)
sleep 1
run nm-applet
run blueman-applet
run pasystray
