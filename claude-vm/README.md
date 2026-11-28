# Claude VM (Ubuntu or Alpine host, Debian 13 + Nix guest)

A local QEMU/KVM VM for Claude Code with no access to the host. It is the
same idea as the Guix VM (6 Nov 2026), with these changes:

- Guest: Debian 13 cloud image instead of Ubuntu 26.04.
- QEMU runs as the system user `claudevm`, not as you. A QEMU escape lands
  in an empty account, not in your home folder (`.ssh`, `.electrum`).
- A host firewall rule (nftables) for `claudevm` blocks loopback, LAN,
  Tailscale and link-local addresses. Root in the guest cannot change it.
  The ufw rules in the guest stay as a second layer.
- Fixed SSH host key, made by `make-vm.sh`. There is no "are you sure?"
  question on the first connection.
- Nix is a single-user install owned by `dev`. There is no root nix-daemon.
  (Debian's own Nix package, 2.26.3, has open bugs where daemon users get root.)
- The VM runs as a service: systemd on Ubuntu, OpenRC on Alpine. Start and
  stop it with `claude-vm`.

## Files

| File | Where it goes | What it does |
|---|---|---|
| `install-host.sh` | run with sudo (Alpine: doas) | packages, user `claudevm`, firewall, service |
| `vm.conf` | `/etc/claude-vm/vm.conf` | CPUS, MEM, DISK, PORT |
| `qemu.sh`, `powerdown.sh` | `/usr/local/lib/claude-vm/` | start and stop QEMU |
| `claude-vm.service` | `/etc/systemd/system/` | the service (Ubuntu) |
| `claude-vm.openrc` | `/etc/init.d/claude-vm` | the service (Alpine) |
| `make-vm.sh` | run as you | image, seed, first boot, ssh settings |
| `user-data.yaml` | in the seed | cloud-init: users, sshd, ufw, packages |
| `provision.sh` | run as you | checks, Nix, home-manager, Claude Code, `~/work` |
| `home/flake.nix`, `home/home.nix` | VM `~/.config/home-manager` | dev's tools |
| `claude-vm` | `~/.local/bin/claude-vm` | start, stop, ssh, console, snapshots |
| `boot-test.sh` | run as you | boots throwaway disk copies with different QEMU options |

Files in `/var/lib/claude-vm` (owner `claudevm`, mode 0700): `disk.qcow2`,
`first-boot.log` (console of the first boot).

QEMU has no default devices (`-nodefaults`) except one standard VGA card.
Debian's GRUB needs the VGA BIOS: without it the guest restarted right
after GRUB (found with `boot-test.sh` on 15 Nov 2026).

## Make the VM

    sudo ./install-host.sh
    ./make-vm.sh

`make-vm.sh` downloads the image, does the first boot in your terminal
(5-15 minutes), starts the service, then runs `provision.sh`. That copies
`~/work.tar.gz` into the VM and unpacks it there (not on the host).
If your SSH key has a passphrase and no agent has it, ssh asks once for
`admin` and once for `dev` (the connections are shared, `ControlMaster`).

`provision.sh` also tests the isolation: it starts a small web server on the
host's 127.0.0.1 and checks that the VM cannot reach it, first with the guest
firewall on, then for a moment with the guest firewall off (so only the host
rule is left). If either test reaches the server, it stops with an error.

Then log in to Claude once and save a clean snapshot:

    ssh claude-vm
    cd ~/work && claude          # open the URL on the host, paste the code
    exit
    claude-vm stop
    claude-vm snapshot base

## Daily use

    claude-vm start
    ssh claude-vm                # then: cd ~/work && claude
    claude-vm stop

A web server that Claude starts in the VM, for example on port 8000:

    ssh -N -L 8000:127.0.0.1:8000 claude-vm      # then open http://127.0.0.1:8000

Go back to the clean state: `claude-vm stop && claude-vm restore base`.

## Rules (the same as before)

- No shared folders, no virtiofs, no USB passthrough, no `ssh -A`.
- Never copy `.ssh`, `.gnupg` or `.electrum` into the VM.
- `dev` is not in sudo, docker or lxd.
- GitHub from the VM: a deploy key made in the VM, for one repo. Not your
  account key.
- Read everything that comes out of the VM before you use it on the host,
  most of all scripts and dotfiles.

## Updates

- Debian security updates: automatic (unattended-upgrades). A new kernel
  needs a reboot: `claude-vm admin sudo reboot`.
- Claude Code updates itself.
- Nix tools: `ssh claude-vm`, then `cd ~/.config/home-manager && nix flake update && home-manager switch`.
  Or change `home/home.nix` here and run `./provision.sh`.
- Nix itself: `ssh claude-vm`, then `nix upgrade-nix`.

## If something fails

- First boot hangs: in the terminal, push Ctrl-] then x. Then `claude-vm destroy` and `./make-vm.sh` again.
- First boot ends without the line "CLAUDE-VM: first boot setup done":
  `make-vm.sh` stops and shows the end of `first-boot.log`. If the guest
  restarts right after GRUB, run `./boot-test.sh` to compare QEMU options.
- The service does not start: `journalctl -u claude-vm -b` (Alpine:
  `doas cat /var/log/claude-vm.log`). If a line under "Extra limits" in
  `claude-vm.service` is the cause, remove it, then run
  `sudo ./install-host.sh` again.
- No ssh: `claude-vm console` shows the boot messages.
- DNS in the VM stops working after a network change: run
  `sudo ./install-host.sh` again. It reads the host's nameservers from
  `/etc/resolv.conf`.
- Start over: `claude-vm stop`, `claude-vm destroy`, `./make-vm.sh`.

## Alpine (OpenRC)

`install-host.sh` sees `/etc/alpine-release` and installs the Alpine
packages and `claude-vm.openrc` as `/etc/init.d/claude-vm`. `sudo` in these
scripts is the doas shim (`doas-sudo-shim`). Everything else is the same.

OpenRC has no equivalent of most of the systemd "Extra limits". On Alpine the
VM keeps: QEMU as `claudevm`, `no_new_privs`, umask 077, QEMU's seccomp
sandbox and the nft rule. It loses ProtectSystem, ProtectHome, PrivateTmp,
DeviceAllow and the other Protect/Restrict options. Keep your home folder at
mode 750 (install-host.sh warns if it is not), since ProtectHome is gone.
