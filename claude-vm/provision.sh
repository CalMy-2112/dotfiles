#!/bin/bash
# Set up the running Claude VM from the host:
#   - check the first boot and the isolation (host rule and guest firewall)
#   - Nix (single user, owned by dev) and home-manager (home/ folder here)
#   - Claude Code (native installer, updates itself)
#   - ~/work from work.tar.gz (unpacked only inside the VM)
#
#   ./provision.sh
#
# make-vm.sh runs it. You can run it again: it skips what is done, and it
# copies home/ again and runs "home-manager switch" (the copy here is the
# master; changes made inside the VM to ~/.config/home-manager are lost).
#
# Env: WORK_TAR=path   archive for ~/work (default ~/work.tar.gz)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
WORK_TAR=${WORK_TAR:-$HOME/work.tar.gz}
HM=github:nix-community/home-manager/release-26.05

die() { echo "provision.sh: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

PORT=2222
# shellcheck source=vm.conf
[ -r /etc/claude-vm/vm.conf ] && . /etc/claude-vm/vm.conf

step "wait for ssh"
# Wait for the sshd banner, without a login (a key with a passphrase would
# make a login loop ask again and again). QEMU accepts the TCP connection
# before sshd runs, so only "SSH-" counts.
for i in $(seq 1 60); do
  if timeout 5 bash -c "exec 3<>/dev/tcp/127.0.0.1/$PORT && head -c 4 <&3 | grep -q SSH-" 2>/dev/null; then
    break
  fi
  [ "$i" -lt 60 ] || die "no ssh to the VM after 5 minutes. Look at the console: claude-vm console"
  sleep 5
done
# The first login opens a shared connection (ControlMaster in
# ~/.ssh/claude-vm.conf): at most one passphrase question per user.
ssh claude-vm-admin true
ssh claude-vm true

step "first boot result"
ssh claude-vm-admin 'sudo python3 -' <<'PY'
import json, sys
r = json.load(open("/var/lib/cloud/data/result.json"))["v1"]
print("datasource:", r.get("datasource"))
errors = r.get("errors") or []
for e in errors:
    print("cloud-init error:", e)
if errors:
    print("More: sudo less /var/log/cloud-init-output.log")
    sys.exit(1)
print("cloud-init: no errors")
PY

step "users, sshd, firewall in the VM"
ssh claude-vm-admin 'bash -s' <<'EOF'
set -eu
fail() { echo "FAIL: $*" >&2; exit 1; }
sudo ufw status | grep -q '^Status: active' || fail "ufw is not active"
if id -nG dev | grep -qwE 'sudo|adm|root|wheel|staff|lxd|docker'; then
  fail "dev is in an admin group: $(id dev)"
fi
if sudo -l -U dev | grep -q 'may run'; then fail "dev has sudo rights"; fi
[ "$(stat -c %U /nix)" = dev ] || fail "/nix does not belong to dev"
[ -e /etc/cloud/cloud-init.disabled ] || fail "cloud-init is not turned off"
sudo sshd -T | grep -qx 'passwordauthentication no' || fail "sshd allows passwords"
sudo sshd -T | grep -qx 'allowtcpforwarding local' || fail "sshd allows remote forwarding"
echo "OK: ufw on, dev has no sudo, /nix belongs to dev, sshd uses keys only"
EOF
if ssh claude-vm 'sudo -n true' 2>/dev/null; then die "dev can use sudo"; fi

step "network isolation"
# A test server on the host's 127.0.0.1. Inside the VM, 10.0.2.2 is the
# host's 127.0.0.1. Both firewall layers must block it.
srvdir=$(mktemp -d)
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$srvdir" >/dev/null 2>&1 &
srv=$!
trap 'kill "$srv" 2>/dev/null; rm -rf "$srvdir"' EXIT
sleep 1
probe="if curl -s -m 5 -o /dev/null http://10.0.2.2:$port/; then echo REACHED; else echo BLOCKED; fi"
# shellcheck disable=SC2029  # $probe is meant to expand here
r=$(ssh claude-vm "$probe")
[ "$r" = BLOCKED ] || die "the VM (dev) reached the host's 127.0.0.1:$port"
echo "guest firewall on:  host 127.0.0.1 blocked"
# Now with the guest firewall off for a moment, so only the host rule is left.
# shellcheck disable=SC2029
r=$(ssh claude-vm-admin "sudo ufw disable >/dev/null; $probe; sudo ufw --force enable >/dev/null")
[ "$r" = BLOCKED ] || die "with the guest firewall off, the VM reached the host: the host rule does not work"
ssh claude-vm-admin 'sudo ufw status | grep -q "^Status: active"' || die "ufw did not come back on"
echo "guest firewall off: host 127.0.0.1 blocked (host rule works)"
code=$(ssh claude-vm 'curl -s -m 20 -o /dev/null -w "%{http_code}" https://api.anthropic.com/ || true')
[ "$code" != 000 ] || die "the VM cannot reach https://api.anthropic.com (DNS or internet)"
echo "internet: OK (api.anthropic.com answered $code)"
kill "$srv" 2>/dev/null || true

step "Nix (single user) for dev"
ssh claude-vm 'bash -s' <<'EOF'
set -euo pipefail
mkdir -p ~/.config/nix
grep -qs '^experimental-features' ~/.config/nix/nix.conf \
  || echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
if [ ! -e ~/.nix-profile/bin/nix ]; then
  curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/nix-install https://nixos.org/nix/install
  sh /tmp/nix-install --no-daemon --yes --no-channel-add
  rm -f /tmp/nix-install
fi
# PATH for all shells, also "ssh claude-vm cmd" (Debian's .bashrc stops
# early when the shell is not interactive, so this goes at the top).
marker='# claude-vm: PATH for all shells'
if ! grep -qF "$marker" ~/.bashrc; then
  {
    printf '%s\n' "$marker" \
      '[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ] && . "$HOME/.nix-profile/etc/profile.d/nix.sh"' \
      'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac' \
      ''
    cat ~/.bashrc
  } > ~/.bashrc.new
  mv ~/.bashrc.new ~/.bashrc
fi
. ~/.nix-profile/etc/profile.d/nix.sh
nix --version
EOF

step "home-manager (from $here/home)"
ssh claude-vm 'mkdir -p ~/.config/home-manager'
scp -q "$here/home/flake.nix" "$here/home/home.nix" claude-vm:.config/home-manager/
# shellcheck disable=SC2029
ssh claude-vm "bash -s -- $HM" <<'EOF'
set -euo pipefail
. ~/.nix-profile/etc/profile.d/nix.sh
cd ~/.config/home-manager
if command -v home-manager >/dev/null; then
  home-manager switch -b hm-backup --flake .#dev
else
  nix run "$1" -- switch -b hm-backup --flake .#dev
fi
EOF

step "Claude Code"
ssh claude-vm 'bash -s' <<'EOF'
set -euo pipefail
if [ ! -x ~/.local/bin/claude ]; then
  # Download to a file first: "curl | bash" hides a failed download.
  curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/claude-install.sh https://claude.ai/install.sh
  bash /tmp/claude-install.sh
  rm -f /tmp/claude-install.sh
fi
~/.local/bin/claude --version
mkdir -p ~/.claude
if [ ! -e ~/.claude/settings.json ]; then
  printf '{\n  "permissions": {\n    "defaultMode": "auto"\n  }\n}\n' > ~/.claude/settings.json
fi
EOF

step "work folder"
if [ ! -f "$WORK_TAR" ]; then
  echo "no $WORK_TAR, skipped"
elif ssh claude-vm '[ -d ~/work ] && [ -n "$(ls -A ~/work)" ]'; then
  echo "the work folder in the VM is not empty, skipped (no overwrite)"
else
  # Not unpacked on the host: the archive came out of the old VM.
  scp -q "$WORK_TAR" claude-vm:work.tar.gz
  ssh claude-vm 'bash -s' <<'EOF'
set -euo pipefail
top=$(tar -tzf ~/work.tar.gz | sed -e 's#^\./##' -e '/^$/d' | cut -d/ -f1 | sort -u)
if [ "$top" = work ]; then
  tar -xzf ~/work.tar.gz -C ~ --no-same-owner
else
  echo "the archive has no top folder 'work' (it has: $(echo $top)); unpacking into ~/work"
  mkdir -p ~/work
  tar -xzf ~/work.tar.gz -C ~/work --no-same-owner
fi
rm -f ~/work.tar.gz
echo "~/work: $(find ~/work -type f | wc -l) files"
EOF
fi

cat <<'EOF'

== Done. Next:
  1. Log in to Claude once:   ssh claude-vm    then:   cd ~/work && claude
     (Claude prints a URL. Open it in a browser on the host, then paste the code.)
  2. Make the clean snapshot:  claude-vm stop && claude-vm snapshot base
     Go back to it later:      claude-vm stop && claude-vm restore base
EOF
