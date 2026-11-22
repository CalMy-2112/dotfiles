#!/usr/bin/env bash
# ~/.config/xmobar/status.sh: a port of Qubes OS's qubes-i3status.py
# (github.com/QubesOS/qubes-desktop-linux-i3-settings-qubes) for xmobar.
# xmobar runs it once (CommandReader) and shows each line it prints.
#
# Same items, formats and timing as Qubes, minus the qube count (no qubes
# here), plus Wi-Fi in the slot of Qubes' (disabled) network item:
#   Disk free: 812G | Wifi: 71% | Bat: 62% AC | Load: 0.52 | Volume: 40 | 2026-11-22 02:20:15
# The loop runs every second; the time is redone every second, the other
# items every 2 seconds, and disk on every 60th loop, as in Qubes' painter().
# An item that can't be read is left out, as in Qubes.

# i3bar's default separator: a 9px block with a 1px vertical line, 4px from
# its left edge, kept clear of the top and bottom of the bar.
SEP='<hspace=4/><box type=Left width=1 mt=4 mb=4 color=#2d732d><hspace=5/></box>'

status_disk() {
  # Free space on / in binary units, cut down (not rounded) like Qubes' ">>".
  local free
  free=$(df -B1 --output=avail / 2>/dev/null | tail -n 1 | tr -d ' ') || return
  [ -n "$free" ] || return
  if   (( free >= 1 << 40 )); then echo "Disk free: $(( free >> 40 ))T"
  elif (( free >= 1 << 30 )); then echo "Disk free: $(( free >> 30 ))G"
  elif (( free >= 1 << 20 )); then echo "Disk free: $(( free >> 20 ))M"
  elif (( free >= 1 << 10 )); then echo "Disk free: $(( free >> 10 ))K"
  else                             echo "Disk free: ${free} Bytes"
  fi
}

status_wifi() {
  # Link quality from /proc/net/wireless is out of 70.
  awk 'NR == 3 { q = $3 + 0; printf "Wifi: %d%%\n", q * 100 / 70; found = 1 }
       END { if (!found) print "Wifi: off" }' /proc/net/wireless 2>/dev/null
}

status_bat() {
  # Same sums as Qubes: energy_* if present, else charge_* x voltage_now.
  local b now=0 full=0 found=0 v c cf pct ac=""
  for b in /sys/class/power_supply/BAT*; do
    [ -d "$b" ] || continue
    found=1
    if [ -r "$b/energy_now" ] && [ -r "$b/energy_full" ]; then
      now=$(( now + $(<"$b/energy_now") ))
      full=$(( full + $(<"$b/energy_full") ))
    elif [ -r "$b/charge_now" ] && [ -r "$b/voltage_now" ]; then
      v=$(<"$b/voltage_now"); c=$(<"$b/charge_now")
      now=$(( now + v * c / 1000000 ))
      if [ -r "$b/charge_full" ]; then
        cf=$(<"$b/charge_full")
        full=$(( full + v * cf / 1000000 ))
      fi
    fi
  done
  (( found )) || return
  if (( full == 0 )); then pct=0; else pct=$(( 100 * now / full )); fi
  for b in /sys/class/power_supply/ADP* /sys/class/power_supply/AC*; do
    [ -r "$b/online" ] && [ "$(<"$b/online")" = 1 ] && ac=" AC"
  done
  echo "Bat: ${pct}%${ac}"   # no colours (Qubes turns it red/yellow when low)
}

status_load() {
  local load _
  read -r load _ < /proc/loadavg && echo "Load: $load"
}

status_volume() {
  # PipeWire first (what the volume keys change), then Qubes' amixer method.
  local mute vol
  if mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null) &&
     vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null); then
    if [ "$mute" = "Mute: yes" ]; then echo "Volume: mute"; return; fi
    vol=$(grep -o '[0-9]*%' <<<"$vol" | head -n 1)
    [ -n "$vol" ] && { echo "Volume: ${vol%\%}"; return; }
  fi
  amixer sget Master 2>/dev/null | awk '
    match($0, /Playback [0-9]+ \[[0-9]+%\] \[(on|off)\]/) {
      s = substr($0, RSTART, RLENGTH); n++
      split(s, p, /[][%]/); pct = p[2]; state = (s ~ /\[on\]$/) ? "on" : "off"
      if (state == "on" && first_on == "") first_on = pct
    }
    END {
      if (n == 0) exit
      if (first_on == "") print "Volume: mute"; else print "Volume: " first_on
    }'
}

loop_count=0
disk_status=""
heavy=()
while true; do
  if (( loop_count % 2 == 0 )); then
    heavy=()
    if (( loop_count % 60 == 0 )); then
      disk_status=$(status_disk)
    fi
    for item in "$disk_status" "$(status_wifi)" "$(status_bat)" \
                "$(status_load)" "$(status_volume)"; do
      [ -n "$item" ] && heavy+=("$item")
    done
  fi
  items=("${heavy[@]}" "$(date '+%Y-%m-%d %H:%M:%S')")

  line=""
  for item in "${items[@]}"; do
    if [ -z "$line" ]; then line="$item"; else line="$line$SEP$item"; fi
  done
  printf '%s\n' "$line"

  loop_count=$(( loop_count + 1 ))
  sleep 1
done
