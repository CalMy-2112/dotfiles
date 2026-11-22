#!/bin/sh
# Prints an empty space as wide as trayer. xmonad puts it between the
# workspace numbers and the window title, where trayer sits on top of it.
width=$(xprop -name panel 2>/dev/null |
  sed -n 's/.*program specified minimum size: \([0-9]*\) by.*/\1/p')
[ -n "$width" ] && echo "<hspace=$((width + 4))/>"   # +4: a little air after the icons
