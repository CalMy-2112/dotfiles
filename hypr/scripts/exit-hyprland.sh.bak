#!/usr/bin/env bash
# Replaces: swaynag -t warning -m 'Exit sway?' -B 'Yes, exit sway' 'swaymsg exit'
# Uses fuzzel (already in your stack) as a dmenu-style confirm prompt instead.

choice=$(printf "Yes, exit Hyprland\nCancel" | fuzzel --dmenu --prompt "Exit Hyprland? ")

if [[ "$choice" == "Yes, exit Hyprland" ]]; then
    hyprctl dispatch exit
fi
