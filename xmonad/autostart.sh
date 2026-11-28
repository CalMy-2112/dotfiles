#!/usr/bin/env bash
# ~/.config/xmonad/autostart.sh — run once at xmonad login (spawnOnce).
# Each line is guarded so a missing program doesn't break the rest.

run() { command -v "$1" >/dev/null 2>&1 && "$@" & }

# ~/.config/xmonad is a symlink into the dotfiles repo; find the repo root
dots="$(dirname "$(dirname "$(readlink -f "$0")")")"

# Normal mouse cursor instead of the X
xsetroot -cursor_name left_ptr

# Sound: on Ubuntu systemd starts PipeWire for the user. Alpine has no
# systemd, so start it here (pipewire, wireplumber and pipewire-pulse).
# It needs XDG_RUNTIME_DIR, which ~/.xinitrc makes sure of.
if [ ! -d /run/systemd/system ] && [ -x /usr/libexec/pipewire-launcher ] &&
   ! pgrep -u "$(id -u)" -x pipewire >/dev/null; then
  /usr/libexec/pipewire-launcher &
fi

# Dark mode for libadwaita apps (Nautilus, Settings) and Firefox: they read
# GNOME's color-scheme setting, not ~/.config/gtk-*/settings.ini. It is kept
# in dconf; setting it every login keeps it in this repo. No-op if the GNOME
# schemas aren't installed.
command -v gsettings >/dev/null 2>&1 &&
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null

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
# The path is Ubuntu's, then Alpine's, then FreeBSD's.
for agent in /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
             /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
             /usr/local/libexec/polkit-gnome-authentication-agent-1; do
  [ -x "$agent" ] && { "$agent" & break; }
done

# Lock screen: xscreensaver locks after 10 min idle, on suspend, and on
# Super+Ctrl+l. Its helper (xscreensaver-systemd) keeps the screen on while
# a browser plays video. Settings are in ~/.Xresources (x11/Xresources).
# X's own blanking is turned off so it doesn't fight xscreensaver.
xset s off
run xscreensaver --no-splash

# Without systemd (FreeBSD, Alpine) there is no xscreensaver-systemd. Do its
# video part here: while a browser or video player plays, tell xscreensaver
# every 50 s that the user is active (its manual gives "--deactivate" for
# this). Not while the screen is blanked or locked, because then it opens
# the unlock dialog. Music players don't count, as with xscreensaver-systemd.
# Locking before suspend is a root job: /etc/rc.suspend on FreeBSD, an
# elogind system-sleep hook on Alpine.
if [ ! -d /run/systemd/system ] && command -v playerctl >/dev/null 2>&1; then
  (
    while sleep 50; do
      xscreensaver-command -time 2>/dev/null | grep -q 'non-blanked' || continue
      for p in $(playerctl -l 2>/dev/null); do
        case $p in
          firefox*|librewolf*|chromium*|brave*|vivaldi*|mpv*|vlc*|celluloid*|haruna*)
            if [ "$(playerctl -p "$p" status 2>/dev/null)" = Playing ]; then
              xscreensaver-command -deactivate >/dev/null 2>&1
              break
            fi ;;
        esac
      done
    done
  ) &
fi

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

# FreeBSD: Wi-Fi (networkmgr runs as root through its own sudoers rule for
# the operator group; -n: never ask for a password) and volume (dsbmixer).
if command -v networkmgr >/dev/null 2>&1; then
  sudo -n networkmgr >/dev/null 2>&1 &
fi
run dsbmixer -i
