#!/bin/bash
# Make the Claude VM. Run as your normal user (it uses sudo where needed),
# after "sudo ./install-host.sh".
#
#   ./make-vm.sh
#
# Steps:
#   1. download the Debian 13 cloud image and check its SHA512 sum
#   2. make a host key for the VM and write the cloud-init seed
#   3. copy the image to /var/lib/claude-vm/disk.qcow2 and make it bigger
#   4. first boot: cloud-init sets up the VM, then the VM turns off;
#      the console log must end with the "setup done" line
#   5. write the ssh settings (ssh claude-vm, ssh claude-vm-admin)
#   6. start the VM and run provision.sh (Nix, Claude Code, ~/work)
#
# Env: SSH_PUBKEY=path  the public key for the VM logins (default
#      ~/.ssh/id_ed25519.pub; the private key must be next to it).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
STATE=/var/lib/claude-vm
LIB=/usr/local/lib/claude-vm
IMG_URL=https://cloud.debian.org/images/cloud/trixie/latest
IMG=debian-13-genericcloud-amd64.qcow2
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/claude-vm
PUBKEY=${SSH_PUBKEY:-$HOME/.ssh/id_ed25519.pub}
KNOWN=$HOME/.ssh/claude-vm_known_hosts
SSHCONF=$HOME/.ssh/claude-vm.conf

die() { echo "make-vm.sh: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }
as_vm() { (cd / && sudo -u claudevm "$@"); }
# The service: systemd (Ubuntu) or OpenRC (Alpine, /etc/init.d/claude-vm).
# On Alpine "sudo" is the doas shim (doas-sudo-shim).
if [ -d /run/systemd/system ]; then
  running() { systemctl is-active --quiet claude-vm; }
  svc() { sudo systemctl "$1" claude-vm; }
else
  running() { rc-service claude-vm status >/dev/null 2>&1; }
  svc() { sudo rc-service claude-vm "$1"; }
fi

[ "$(id -u)" -ne 0 ] || die "run as your normal user, not with sudo"
[ -r /etc/claude-vm/vm.conf ] || die "run 'sudo ./install-host.sh' first"
# shellcheck source=vm.conf
. /etc/claude-vm/vm.conf
[ -r "$PUBKEY" ] || die "no public key $PUBKEY (make one: ssh-keygen -t ed25519), or set SSH_PUBKEY"
PRIVKEY=${PUBKEY%.pub}
[ -r "$PRIVKEY" ] || die "no private key $PRIVKEY next to $PUBKEY"
if sudo test -e "$STATE/disk.qcow2"; then
  die "the VM disk exists already. To make a new VM, first run: claude-vm destroy"
fi
if running; then
  die "the claude-vm service is running; stop it first: claude-vm stop"
fi

step "1. Debian 13 cloud image"
mkdir -p "$CACHE"
curl -fsSL --proto '=https' --tlsv1.2 -o "$CACHE/SHA512SUMS" "$IMG_URL/SHA512SUMS"
grep -E "  $IMG\$" "$CACHE/SHA512SUMS" > "$CACHE/$IMG.sha512" \
  || die "$IMG is not in SHA512SUMS"
if [ -f "$CACHE/$IMG" ] && (cd "$CACHE" && sha512sum --quiet -c "$IMG.sha512") 2>/dev/null; then
  echo "using the image in $CACHE (checksum OK)"
else
  curl -fL --proto '=https' --tlsv1.2 -o "$CACHE/$IMG" "$IMG_URL/$IMG"
  (cd "$CACHE" && sha512sum -c "$IMG.sha512") || die "checksum of $IMG is wrong"
fi

step "2. host key and cloud-init seed"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ssh-keygen -q -t ed25519 -N '' -C claude-vm -f "$tmp/host_ed25519"
python3 - "$here/user-data.yaml" "$tmp/user-data" "$PUBKEY" "$tmp/host_ed25519" <<'PY'
import sys
src, dst, user_pub, host_key = sys.argv[1:5]
values = {
    "@USER_KEY@": open(user_pub).read().strip(),
    "@HOST_KEY_PUB@": open(host_key + ".pub").read().strip(),
    "@HOST_KEY_PRIV@": open(host_key).read().strip(),
}
out = []
for line in open(src).read().splitlines():
    name = line.strip()
    if name in values and "\n" in values[name]:
        # a block value: indent every line like the placeholder line
        indent = line[: len(line) - len(line.lstrip())]
        out += [indent + v for v in values[name].splitlines()]
        continue
    for k, v in values.items():
        if "\n" not in v:
            line = line.replace(k, v)
    out.append(line)
text = "\n".join(out) + "\n"
if any(k in text for k in values):
    sys.exit("make-vm.sh: a placeholder was not replaced")
open(dst, "w").write(text)
PY
cat > "$tmp/meta-data" <<EOF
instance-id: claude-vm-$(date +%Y%m%d-%H%M%S)
local-hostname: claude-vm
EOF
# The NoCloud seed: an ISO labelled "cidata" with user-data and meta-data.
# Alpine can't have cloud-localds (cdrkit) next to virt-install (xorriso),
# so there xorriso makes the same ISO.
if command -v cloud-localds >/dev/null 2>&1; then
  cloud-localds "$tmp/seed.img" "$tmp/user-data" "$tmp/meta-data"
else
  xorriso -as mkisofs -quiet -output "$tmp/seed.img" -volid cidata -joliet -rock \
    "$tmp/user-data" "$tmp/meta-data"
fi

step "3. disk ($DISK)"
sudo install -o claudevm -g claudevm -m 0600 "$CACHE/$IMG" "$STATE/disk.qcow2"
as_vm qemu-img resize -q "$STATE/disk.qcow2" "$DISK"
sudo install -o claudevm -g claudevm -m 0600 "$tmp/seed.img" "$STATE/seed.img"

step "4. first boot"
echo "cloud-init installs packages and sets up the users and the firewall."
echo "Then the VM turns off by itself (about 5-15 minutes)."
echo "To stop QEMU by force: Ctrl-] then x."
sudo nft -f /etc/claude-vm/claudevm.nft
as_vm "$LIB/qemu.sh" first-boot || die "QEMU stopped with an error"
# QEMU also stops with no error when the guest restarts (-no-reboot), so
# check that cloud-init really got to the end.
if ! sudo grep -q 'CLAUDE-VM: first boot setup done' "$STATE/first-boot.log"; then
  echo >&2
  echo "The first boot did not finish the setup. Last lines of the console:" >&2
  sudo tail -n 25 "$STATE/first-boot.log" | tr -d '\r' >&2
  echo >&2
  die "full log: sudo less $STATE/first-boot.log   To start again: claude-vm destroy && ./make-vm.sh"
fi
echo "first boot: setup done"
# The seed has the VM's private host key; the VM does not need it any more.
sudo rm -f "$STATE/seed.img"

step "5. ssh settings"
install -d -m 0700 "$HOME/.ssh"
printf 'claude-vm %s\n' "$(cut -d' ' -f1,2 "$tmp/host_ed25519.pub")" > "$KNOWN"
chmod 0600 "$KNOWN"
cat > "$SSHCONF" <<EOF
# Made by make-vm.sh (Claude VM).
Host claude-vm claude-vm-admin
    HostName 127.0.0.1
    Port $PORT
    HostKeyAlias claude-vm
    UserKnownHostsFile $KNOWN
    StrictHostKeyChecking yes
    IdentityFile $PRIVKEY
    IdentitiesOnly yes
    ForwardAgent no
    ForwardX11 no
    PermitLocalCommand no
    ServerAliveInterval 30
    ControlMaster auto
    ControlPath ~/.ssh/cm-claude-vm-%r
    ControlPersist 120
Host claude-vm
    User dev
Host claude-vm-admin
    User admin
EOF
chmod 0600 "$SSHCONF"
cfg=$HOME/.ssh/config
inc="Include ~/.ssh/claude-vm.conf"
if ! grep -qxF "$inc" "$cfg" 2>/dev/null; then
  # Include must come before the first Host line, so put it at the top.
  if [ -f "$cfg" ]; then
    cp -p "$cfg" "$cfg.bak-claude-vm"
    echo "backup of your ssh config: $cfg.bak-claude-vm"
  fi
  {
    echo "$inc"
    echo
    if [ -f "$cfg" ]; then cat "$cfg"; fi
  } > "$cfg.new"
  chmod 0600 "$cfg.new"
  mv "$cfg.new" "$cfg"
fi
mkdir -p "$HOME/.local/bin"
ln -sfn "$here/claude-vm" "$HOME/.local/bin/claude-vm"
echo "control command: claude-vm (in ~/.local/bin)"

step "6. start the VM and provision it"
svc start
"$here/provision.sh"
