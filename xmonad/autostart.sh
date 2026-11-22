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

# System tray: in the bar, between the workspace numbers and the window title.
#   --distance = characters before it x character width
#              = (1 space + 27 workspace chars + 5 separator chars) x 9.6px = 317
#   (JetBrains Mono at 16px is 9.6px per character)
#   --height   = xmobar's bar height (TopH 28), minus 1 for its bottom border
run trayer --edge top --align left --distancefrom left --distance 317 \
  --widthtype request --height 27 --iconspacing 6 \
  --SetDockType true --SetPartialStrut false --expand true \
  --transparent true --alpha 0 --tint 0x0b0b0b --monitor primary

# Tray applets (give trayer a moment to start). Most applets now use the
# StatusNotifier tray standard, which trayer doesn't speak; snixembed
# translates them into icons trayer can show.
sleep 1
run snixembed
sleep 0.5
run nm-applet
run blueman-applet
run pasystray
