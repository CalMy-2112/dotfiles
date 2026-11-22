#!/bin/sh
# Prints an empty space as wide as trayer, so xmobar's right-hand text ends
# where the tray icons begin (trayer sits on top of the bar's right end).
width=$(xprop -name panel 2>/dev/null |
  sed -n 's/.*program specified minimum size: \([0-9]*\) by.*/\1/p')
echo "<hspace=$(( ${width:-0} + 8 ))/>"
