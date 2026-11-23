#!/usr/bin/env bash
# ~/.config/xmonad/autostart.sh — run once at xmonad login (spawnOnce).
# Each line is guarded so a missing program doesn't break the rest.

run() { command -v "$1" >/dev/null 2>&1 && "$@" & }

# ~/.config/xmonad is a symlink into the dotfiles repo; find the repo root
dots="$(dirname "$(dirname "$(readlink -f "$0")")")"

# Normal mouse cursor instead of the X
xsetroot -cursor_name left_ptr

# Wallpaper from the repo's wallpapers/ folder
wall="$dots/wallpapers/hyprland-girl.jpg"
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

# Lock screen: xscreensaver locks after 10 min idle, on suspend, and on
# Super+Ctrl+l. Its helper (xscreensaver-systemd) keeps the screen on while
# a browser plays video. Settings are in ~/.Xresources (x11/Xresources).
# X's own blanking is turned off so it doesn't fight xscreensaver.
xset s off
run xscreensaver --no-splash

# System tray: at the right end of the bar, like i3bar. i3's default tray
# padding is 2px above, below and to the right, so in the 24px bar:
#   --height 20 (icons 20px), --distance 2 from the top, --margin 2 from
#   the right edge. xmobar/trayer-padding.sh keeps the status text clear.
run trayer --edge top --align right --margin 2 --distancefrom top --distance 2 \
  --widthtype request --height 20 --iconspacing 2 \
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
