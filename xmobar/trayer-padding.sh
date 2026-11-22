#!/bin/sh
# Prints an empty space as wide as trayer plus its 2px right margin, so the
# status text ends where the tray begins (trayer sits at the bar's right end).
width=$(xprop -name panel 2>/dev/null |
  sed -n 's/.*program specified minimum size: \([0-9]*\) by.*/\1/p')
[ -n "$width" ] && echo "<hspace=$((width + 2))/>"
