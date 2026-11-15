#!/bin/bash
# Find which QEMU options let the Debian guest boot on this host.
# Run as your normal user:   ./boot-test.sh
#
# It stops claude-vm.service, then boots throwaway copies (qcow2 overlays) of
# /var/lib/claude-vm/disk.qcow2 with different options, 30 s each, with the
# serial console in a log. The real disk does not change. About 2 minutes.
set -euo pipefail

STATE=/var/lib/claude-vm
WORK=$STATE/boot-test
T=${T:-30}

as_vm() { (cd / && sudo -u claudevm "$@"); }

[ "$(id -u)" -ne 0 ] || { echo "run as your normal user, not with sudo" >&2; exit 1; }
sudo test -f "$STATE/disk.qcow2" || { echo "no $STATE/disk.qcow2" >&2; exit 1; }
if systemctl is-active --quiet claude-vm; then
  echo "stopping claude-vm.service"
  sudo systemctl stop claude-vm
fi

echo "== host"
uname -r
qemu-system-x86_64 --version | head -1
grep -m1 'model name' /proc/cpuinfo
echo

# name | options (all runs also get: -display none -monitor none -nic none
#                 -serial file:LOG -no-reboot and the overlay disk)
variants=(
  "1 old options (nodefaults, no VGA)|-machine q35,accel=kvm -cpu host -smp 4 -m 8G -nodefaults"
  "2 new options (nodefaults + vga std)|-machine q35,accel=kvm -cpu host -smp 4 -m 8G -nodefaults -vga std"
  "3 default devices, but no VGA|-machine q35,accel=kvm -cpu host -smp 4 -m 8G -vga none"
)

as_vm rm -rf "$WORK"
as_vm mkdir -p "$WORK"
results=()
n=0
for v in "${variants[@]}"; do
  n=$((n + 1))
  name=${v%%|*}
  opts=${v#*|}
  log=$WORK/serial-$n.log
  echo "== $name (up to $T s)"
  as_vm qemu-img create -q -f qcow2 -F qcow2 -b "$STATE/disk.qcow2" "$WORK/overlay.qcow2"
  start=$(date +%s)
  set +e
  # shellcheck disable=SC2086  # $opts is a list of options
  as_vm timeout "$T" qemu-system-x86_64 $opts \
    -display none -monitor none -nic none -no-reboot \
    -drive file="$WORK/overlay.qcow2",if=virtio,format=qcow2 \
    -serial file:"$log" 2> >(sed 's/^/  qemu: /' >&2)
  rc=$?
  set -e
  secs=$(( $(date +%s) - start ))
  if [ "$rc" -eq 124 ]; then
    outcome="still running at ${T}s"
  elif [ "$rc" -eq 0 ]; then
    outcome="QEMU ended after ${secs}s (guest restart or power off)"
  else
    outcome="QEMU error after ${secs}s (exit $rc, see the qemu: lines above)"
  fi
  text=""
  if sudo test -f "$log"; then
    text=$(sudo cat "$log" | tr -d '\r' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g')
  fi
  grub=$(grep -c "Booting \`Debian" <<<"$text" || true)
  linux=$(grep -c 'Linux version' <<<"$text" || true)
  last=$(grep -v '^[[:space:]]*$' <<<"$text" | tail -n 2 | cut -c1-110 | sed 's/^/    | /' || true)
  results+=("$name: $outcome; GRUB 'Booting' lines: $grub; kernel 'Linux version' lines: $linux"$'\n'"$last")
  as_vm rm -f "$WORK/overlay.qcow2"
done

echo
echo "== results"
for r in "${results[@]}"; do echo "$r"; done
echo
echo "== host kernel messages about KVM (last 10)"
sudo dmesg | grep -i -E 'kvm|vmx' | tail -n 10 || true
echo
echo "Logs: sudo ls $WORK (delete with: sudo rm -r $WORK)"
