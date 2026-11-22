#!/usr/bin/env bash
# Ubuntu setup for the gram: xmonad (via startx, next to GNOME) + the cccru theme for
# alacritty, tmux and zsh. Run from anywhere:  bash ~/dots/install-ubuntu.sh
#
# Every config is a symlink into this repo. Anything already in the way is
# moved to <name>.bak.<timestamp> first, never deleted.
set -euo pipefail
dots="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"

sudo apt update
sudo apt install -y \
  xmonad libghc-xmonad-contrib-dev xmobar \
  rofi trayer feh picom dunst flameshot \
  xss-lock i3lock x11-xserver-utils x11-utils xserver-xorg xinit \
  network-manager-gnome blueman pasystray pavucontrol \
  brightnessctl playerctl policykit-1-gnome \
  xdotool wmctrl pulseaudio-utils alsa-utils
# alacritty is left out: 0.16.1 is already installed

link() {  # link <repo path> <target>
  local src="$dots/$1" dst="$2"
  if [ "$(readlink -f "$dst" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
    echo "ok      $dst"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak.$stamp"
    echo "backup  $dst -> $dst.bak.$stamp"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "linked  $dst -> $src"
}

link xmonad                 "$HOME/.config/xmonad"
link xmobar                 "$HOME/.config/xmobar"
link alacritty              "$HOME/.config/alacritty"
link tmux/.tmux.conf.local  "$HOME/.tmux.conf.local"
link zsh/.zshrc             "$HOME/.zshrc"
link x11/xinitrc            "$HOME/.xinitrc"
link x11/Xresources         "$HOME/.Xresources"
# helix: link files one by one so ~/.config/helix/runtime (grammars) stays put
link helix/config.toml       "$HOME/.config/helix/config.toml"
link helix/languages.toml    "$HOME/.config/helix/languages.toml"
link helix/themes            "$HOME/.config/helix/themes"
chmod +x "$dots/xmonad/autostart.sh" "$dots/xmonad/build" "$dots/xmobar/trayer-padding.sh" "$dots/xmobar/status.sh" "$dots/xmobar/ws-scroll.sh" "$dots/x11/xinitrc"

# oh-my-zsh and oh-my-tmux themselves are not in this repo
[ -d "$HOME/.oh-my-zsh" ] || echo "NOTE: ~/.oh-my-zsh is missing; install oh-my-zsh for the zsh theme"
grep -q 'gpakosz' "$HOME/.tmux.conf" 2>/dev/null || echo "NOTE: ~/.tmux.conf is not oh-my-tmux; the tmux theme needs it"

# Compile now so errors show up here rather than at login
xmonad --recompile && echo "OK: xmonad compiled. Start it with: Ctrl+Alt+F3, log in, startx"
