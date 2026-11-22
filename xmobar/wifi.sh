#!/bin/sh
# Wi-Fi signal as a percentage, for xmobar. Link quality in
# /proc/net/wireless is out of 70. Prints "wifi off" when not connected.
awk 'NR == 3 { q = $3 + 0; printf "wifi %d%%\n", q * 100 / 70; found = 1 }
     END { if (!found) print "wifi off" }' /proc/net/wireless
