#!/bin/sh
# Scroll over the workspace buttons, like i3bar: move to the next/previous
# workspace that is in use (has windows, or is the current one), wrapping
# around at the ends.   Usage: ws-scroll.sh next|prev
cur=$(xdotool get_desktop) || exit
used=$( { wmctrl -l | awk '$2 >= 0 { print $2 }'; echo "$cur"; } | sort -n | uniq)
target=$(echo "$used" | awk -v c="$cur" -v d="$1" '
  { a[NR] = $1; if ($1 == c) i = NR }
  END { j = (d == "next") ? i % NR + 1 : (i + NR - 2) % NR + 1; print a[j] }')
[ -n "$target" ] && [ "$target" != "$cur" ] && xdotool set_desktop "$target"
