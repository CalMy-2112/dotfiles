#!/bin/sh
# ExecStop of claude-vm.service. Pushes the guest's power button (ACPI),
# then waits up to 90 s for QEMU to stop. If the guest does not stop,
# systemd stops QEMU when TimeoutStopSec ends.
sock=/run/claude-vm/monitor.sock
[ -S "$sock" ] || exit 0
printf 'system_powerdown\n' | socat -t 2 - UNIX-CONNECT:"$sock" >/dev/null 2>&1 || exit 0
[ -n "${MAINPID:-}" ] || exit 0
i=0
while kill -0 "$MAINPID" 2>/dev/null && [ "$i" -lt 90 ]; do
  sleep 1
  i=$((i + 1))
done
exit 0
