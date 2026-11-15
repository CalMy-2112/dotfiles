#!/bin/sh
# Start the Claude VM. Runs as the user claudevm.
#
#   qemu.sh service      normal start, from claude-vm.service.
#                        Console and monitor are sockets in /run/claude-vm.
#   qemu.sh first-boot   first start with the cloud-init seed (make-vm.sh).
#                        The console is this terminal (and first-boot.log).
#                        Ctrl-] x stops QEMU.
#
# Isolation (the same as the Guix VM):
#   - user network (SLIRP) with IPv6 off; only the guest's ssh port is
#     forwarded, to 127.0.0.1 on the host
#   - no shared folders, no USB, no display; no default devices except a
#     standard VGA card. Debian's GRUB needs its VGA BIOS: without it the
#     guest restarts right after GRUB (boot-test.sh on the gram, 15 Nov 2026).
#   - QEMU's seccomp sandbox: no new privileges, no spawning programs
set -eu

STATE=/var/lib/claude-vm
RUN=/run/claude-vm
CPUS=4
MEM=8G
PORT=2222
# shellcheck source=vm.conf
[ -r /etc/claude-vm/vm.conf ] && . /etc/claude-vm/vm.conf

die() { echo "qemu.sh: $*" >&2; exit 1; }

mode=${1:-service}  # read it now: "set --" below replaces $1

[ "$(id -un)" = claudevm ] || die "run as the user claudevm"
if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
  die "no access to /dev/kvm (is claudevm in the group kvm?)"
fi
[ -f "$STATE/disk.qcow2" ] || die "no disk $STATE/disk.qcow2 (run make-vm.sh)"

set -- \
  -name claude-vm \
  -machine q35,accel=kvm \
  -cpu host -smp "$CPUS" -m "$MEM" \
  -nodefaults -display none -vga std \
  -drive file="$STATE/disk.qcow2",if=virtio,format=qcow2,discard=unmap \
  -nic user,model=virtio-net-pci,ipv6=off,hostfwd=tcp:127.0.0.1:"$PORT"-:22 \
  -device virtio-rng-pci \
  -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny

case $mode in
  service)
    exec qemu-system-x86_64 "$@" \
      -serial unix:"$RUN/serial.sock",server=on,wait=off \
      -monitor unix:"$RUN/monitor.sock",server=on,wait=off
    ;;
  first-boot)
    [ -f "$STATE/seed.img" ] || die "no seed $STATE/seed.img"
    # The console is this terminal and also $STATE/first-boot.log;
    # make-vm.sh looks in the log for the "setup done" line.
    exec qemu-system-x86_64 "$@" \
      -drive file="$STATE/seed.img",if=virtio,format=raw,readonly=on \
      -chardev stdio,id=con,mux=on,logfile="$STATE/first-boot.log" \
      -serial chardev:con -mon chardev=con \
      -echr 29 -no-reboot
    ;;
  *)
    die "usage: qemu.sh service|first-boot"
    ;;
esac
