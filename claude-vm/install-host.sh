#!/bin/bash
# Install the host part of the Claude VM on Ubuntu.
#
#   sudo ./install-host.sh
#
# Run it again after you change vm.conf, qemu.sh, powerdown.sh or
# claude-vm.service, or when /etc/resolv.conf gets a new nameserver.
#
# What it does:
#   - installs QEMU, qemu-img, cloud-localds, nft and socat
#   - makes the system user "claudevm". QEMU runs as this user, not as you,
#     so a QEMU escape does not land in your home folder.
#   - writes a host firewall table for that user: no connections to
#     loopback, LAN, Tailscale or link-local addresses (DNS to your
#     resolver is the only exception). The guest cannot change this rule.
#   - installs qemu.sh, powerdown.sh and claude-vm.service
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
VM_USER=claudevm
STATE=/var/lib/claude-vm
LIB=/usr/local/lib/claude-vm
ETC=/etc/claude-vm

die() { echo "install-host.sh: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo $0"
[ -e /dev/kvm ] || die "/dev/kvm is missing. Turn on VT-x in the firmware setup, then check: ls -l /dev/kvm"

echo "== packages"
apt-get update -qq || echo "WARNING: apt-get update failed; trying the install anyway"
apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils nftables socat curl

echo "== user $VM_USER"
if ! id "$VM_USER" >/dev/null 2>&1; then
  useradd --system --home-dir "$STATE" --no-create-home \
    --shell /usr/sbin/nologin "$VM_USER"
fi
getent group kvm >/dev/null || die "there is no group kvm (ls -l /dev/kvm shows the group)"
usermod -aG kvm "$VM_USER"
install -d -o "$VM_USER" -g "$VM_USER" -m 0700 "$STATE"

# The VM user must not be able to read your home folder.
if [ -n "${SUDO_USER:-}" ]; then
  home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  mode=$(stat -c %a "$home")
  case $mode in
    *[1-7]) echo "WARNING: $home is readable by other users (mode $mode)."
            echo "         Fix it with: chmod 750 $home" ;;
  esac
fi

echo "== settings ($ETC/vm.conf)"
install -d -m 0755 "$ETC"
if [ ! -e "$ETC/vm.conf" ]; then
  install -m 0644 "$here/vm.conf" "$ETC/vm.conf"
else
  echo "keeping the existing $ETC/vm.conf"
fi
# shellcheck source=vm.conf
. "$ETC/vm.conf"

echo "== host firewall for $VM_USER ($ETC/claudevm.nft)"
# QEMU's user network sends the guest's DNS queries (to 10.0.2.3) to the
# first IPv4 nameserver in the host's /etc/resolv.conf. On Ubuntu that is
# usually systemd-resolved at 127.0.0.53, which the rule below would block,
# so allow port 53 to each IPv4 nameserver, and nothing else.
dns_rules=""
while read -r key ns _; do
  [ "$key" = nameserver ] || continue
  case $ns in
    *:*) continue ;;  # IPv6: QEMU's user network here is IPv4 only
  esac
  dns_rules+="    meta skuid \"$VM_USER\" ip daddr $ns udp dport 53 accept"$'\n'
  dns_rules+="    meta skuid \"$VM_USER\" ip daddr $ns tcp dport 53 accept"$'\n'
done < /etc/resolv.conf
[ -n "$dns_rules" ] || echo "WARNING: no IPv4 nameserver in /etc/resolv.conf; DNS in the VM may not work"

cat > "$ETC/claudevm.nft.new" <<EOF
#!/usr/sbin/nft -f
# Made by install-host.sh. Outgoing filter for the user $VM_USER, which runs
# QEMU for the Claude VM. All guest traffic leaves the host from that user.
# Replies on connections that you open to the VM (ssh to 127.0.0.1:$PORT)
# are "established", so they pass.
add table inet claudevm
delete table inet claudevm
table inet claudevm {
  chain out {
    type filter hook output priority 0; policy accept;
    meta skuid "$VM_USER" ct state established,related accept
${dns_rules}    meta skuid "$VM_USER" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 255.255.255.255 } reject
    meta skuid "$VM_USER" ip6 daddr { ::, ::1, fc00::/7, fe80::/10, ff00::/8 } reject
  }
}
EOF
nft -c -f "$ETC/claudevm.nft.new" || die "nft does not accept the new rules"
mv "$ETC/claudevm.nft.new" "$ETC/claudevm.nft"
chmod 0644 "$ETC/claudevm.nft"
nft -f "$ETC/claudevm.nft"

echo "== scripts and service"
install -d -m 0755 "$LIB"
install -m 0755 "$here/qemu.sh" "$LIB/qemu.sh"
install -m 0755 "$here/powerdown.sh" "$LIB/powerdown.sh"
install -m 0644 "$here/claude-vm.service" /etc/systemd/system/claude-vm.service
systemctl daemon-reload

echo
echo "Done. Next, as your normal user (not with sudo):  ./make-vm.sh"
