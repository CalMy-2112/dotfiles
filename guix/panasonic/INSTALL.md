# Guix System on the CF-SZ5: install steps

Files in this folder:

- `config.scm`: the system (kernel, Wi-Fi firmware, disks, user, Bluetooth,
  JP keyboard, tuigreet login screen, console font, zsh as login shell,
  circular scrolling).
- `circscroll.c`: the circular-scrolling program. config.scm builds it.
- `home.scm`: your programs, user services and dotfiles (Hyprland, Waybar,
  PipeWire, zsh + oh-my-zsh, tmux + oh-my-tmux, wallpaper, Neovim tools).
- `../channels.scm`: Guix + nonguix. Used only for the first install.

home.scm also uses these files from the repository, if they are there:
`zsh/.zshrc`, `tmux/.tmux.conf.local`, `wallpapers/bay.jpg` and the `nvim/`
folder. Section F says what to put there.

Change `YOU/DOTS` below to your GitHub repository. These steps expect this
folder to be at `guix/panasonic/` in that repository, with `channels.scm`
in `guix/`.

The install erases the internal disk.


## A. Before you start (on Debian, now)

1. Put this `guix` folder in your dotfiles repository and push it to GitHub.

2. Download the installer:

       wget https://ftp.gnu.org/gnu/guix/guix-system-install-1.5.0.x86_64-linux.iso

   If you get "404", find the current file name on https://guix.gnu.org/download/

3. Find the USB stick. It is the line with TRAN = usb:

       lsblk -o NAME,SIZE,MODEL,TRAN

4. Write the installer to the stick. Change `sdX` to the stick
   (for example `sdb`). CAUTION: dd erases the disk you name.

       sudo umount /media/osho/CALSANDISK
       sudo dd if=guix-system-install-1.5.0.x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync

5. Connect the Ethernet cable to the laptop.


## B. Boot the installer

1. Restart. Press F2 at the Panasonic logo to open the setup utility.
   Make sure that Secure Boot is off (you turned it off for Debian).
   Select the USB stick as the boot device.
2. When the installer menu shows, press Ctrl+Alt+F3. You get a root shell.
3. Japanese keyboard:

       loadkeys jp106

4. Make sure that the laptop booted in UEFI mode. This command must list files:

       ls /sys/firmware/efi

5. Network. Find the Ethernet name (it starts with "e", for example `enp0s31f6`):

       ip -br link
       ip link set enp0s31f6 up
       dhclient -v enp0s31f6
       ping -c 3 gnu.org

   If `dhclient` is not found, use `dhcpcd enp0s31f6`.


## C. Disk

1. Find the internal disk. It is the line with TRAN = sata (probably `sda`):

       lsblk -o NAME,SIZE,MODEL,TRAN

2. Partition and format. If the disk is not `sda`, change the first line.

       DISK=/dev/sda
       parted -s -a optimal $DISK mklabel gpt \
         mkpart ESP fat32 1MiB 513MiB set 1 esp on \
         mkpart root ext4 513MiB 100%
       mkfs.fat -F32 -i 1234ABCD ${DISK}1
       mkfs.ext4 -L guix-root ${DISK}2

   config.scm finds the disks by the label `guix-root` and the ID `1234-ABCD`.
   Do not change one without the other.

3. Mount, keep the installer's downloads on the disk, and make the swap file:

       mount LABEL=guix-root /mnt
       mkdir -p /mnt/boot/efi
       mount ${DISK}1 /mnt/boot/efi
       herd start cow-store /mnt
       dd if=/dev/zero of=/mnt/swapfile bs=1MiB count=4096
       chmod 600 /mnt/swapfile
       mkswap /mnt/swapfile
       swapon /mnt/swapfile


## D. Install

1. Get your files:

       guix shell git -- git clone https://github.com/YOU/DOTS /mnt/root/dots
       mkdir -p /mnt/etc
       cp /mnt/root/dots/guix/panasonic/config.scm /mnt/root/dots/guix/panasonic/circscroll.c /mnt/etc/

   config.scm needs circscroll.c in the same folder.

2. Trust the nonguix build server, so that the kernel and firmware download
   ready-built:

       wget -O /tmp/nonguix.pub https://substitutes.nonguix.org/signing-key.pub
       cat /tmp/nonguix.pub
       guix archive --authorize < /tmp/nonguix.pub

   The `q #...#` value in the output must be the same as in config.scm
   (C1FD53E5...EA98). If it is not, stop and tell me.

3. Install. This takes 30 to 90 minutes.

       mkdir -p /mnt/var/cache/install
       export XDG_CACHE_HOME=/mnt/var/cache/install
       guix time-machine -C /mnt/root/dots/guix/channels.scm -- \
         system init /mnt/etc/config.scm /mnt \
         --substitute-urls='https://ci.guix.gnu.org https://bordeaux.guix.gnu.org https://substitutes.nonguix.org'

   `XDG_CACHE_HOME` keeps a 1 GB download on the disk. Without it, the
   download goes in memory.

   If you see `building ...-linux-6...` (the kernel), nonguix has no
   ready-built kernel for this Guix version yet. Compiling it takes hours.
   You can let it run, or stop it with Ctrl+C and run the same command again
   later.

4. Restart and remove the USB stick:

       reboot


## E. First boot

The tuigreet login screen shows on tty1. It starts Hyprland, and Hyprland is
not installed until step 4. So do steps 1 to 4 on the text login on tty2.

1. Press Ctrl+Alt+F2. At the login prompt, log in as `root`. The password is
   empty. Set the passwords, then log out:

       passwd
       passwd osho
       exit

2. Log in as `osho` at the same prompt. Do not use `su osho`: with su,
   NetworkManager (and later Hyprland) refuses, because you are not logged in
   at the laptop. Wi-Fi now works:

       nmcli device wifi connect "NETWORK NAME" --ask

3. Update Guix. The first time takes 10 to 30 minutes.
   /etc/guix/channels.scm already includes nonguix.

       guix pull
       hash guix

4. Get your files and install your programs:

       guix shell git -- git clone https://github.com/YOU/DOTS ~/dots
       guix home reconfigure ~/dots/guix/panasonic/home.scm

   This prints `home.scm: Hyprland 0.55.x (reads hyprland.lua)`.
   If a repository file from section F is missing, it prints
   `... is not in the repository yet; skipped` and continues.
   Guix Home moves old files that it replaces (for example ~/.config/nvim)
   to a backup folder in your home. That is normal.

5. Copy your configs to ~/.config. Change the paths to match your repository:

       mkdir -p ~/.config
       cp -r ~/dots/.config/{hypr,waybar,fuzzel,alacritty,fastfetch,yazi} ~/.config/

6. Change the Fedora parts of the configs. This command finds them:

       grep -rn -E 'systemctl|/usr/|uwsm|dnf|flatpak' ~/.config/hypr ~/.config/waybar ~/.local/bin 2>/dev/null

   - `systemctl suspend`, `reboot`, `poweroff`: change to `loginctl suspend`,
     `loginctl reboot`, `loginctl poweroff`. Guix has no systemd.
   - The polkit agent is at `~/.guix-home/profile/libexec/hyprpolkitagent`.
   - Other `/usr/...` paths: use the command name only.

7. Japanese keyboard in Hyprland. In the `input` part of hyprland.lua:

       kb_layout  = "jp",
       kb_model   = "jp106",

8. Cursor: Guix does not have phinger-cursors, so home.scm packages it and
   sets XCURSOR_PATH. Nothing to download. GTK programs (LibreWolf,
   pavucontrol, blueman) read the cursor from gsettings. Add these to the
   autostart in hyprland.lua (use your XCURSOR_SIZE):

       hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme \"phinger-cursors-dark\"")
       hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 40")

9. Log out (`exit`). Press Ctrl+Alt+F1 and log in at tuigreet. Hyprland
   starts. On tty2 (Ctrl+Alt+F2) you always get a text login. Use it if
   Hyprland does not start.

10. Delete the installer's download folder:

        sudo rm -rf /var/cache/install


## F. Login screen, zsh, tmux, wallpaper, Neovim

Do this on a system that is already installed (or after section E).

1. Put these files in the repository (the same layout as hypr/, waybar/...):

       zsh/.zshrc               the new .zshrc (changed for Guix)
       tmux/.tmux.conf.local    your .tmux.conf.local, no changes
       wallpapers/bay.jpg       your wallpaper
       nvim/                    already there

   Do not add .tmux.conf: it is the oh-my-tmux file, and home.scm gets the
   same version from GitHub. Then push.

2. Apply the system part: tuigreet on tty1, the Terminus 16x32 console
   font, zsh as login shell, less boot text:

       sudo guix system reconfigure ~/dots/guix/panasonic/config.scm

3. Apply the home part: oh-my-zsh, plugins, oh-my-tmux, the wallpaper, the
   Neovim link and tools:

       guix home reconfigure ~/dots/guix/panasonic/home.scm

4. If tmux is running, stop it (`tmux kill-server`). Then reboot:

       sudo reboot

   tuigreet shows on tty1. If it does not work, press Ctrl+Alt+F2 and log
   in there, or select the older system in the GRUB menu.

5. Neovim tools that are not in Guix. pyright, bashls and ts_ls from
   your lsp.lua come from npm (Node is in home.scm):

       npm install -g --prefix ~/.local pyright bash-language-server typescript typescript-language-server

   asm-lsp: `cargo install asm-lsp` (Rust is in home.scm).
   nixd and hls are not set up: they are for Nix and Haskell.

6. Swank for your Lisp autocmd (`ql:quickload :swank`) needs Quicklisp:

       curl -o /tmp/quicklisp.lisp https://beta.quicklisp.org/quicklisp.lisp
       sbcl --non-interactive --load /tmp/quicklisp.lisp \
         --eval '(quicklisp-quickstart:install)' \
         --eval '(ql-util:without-prompting (ql:add-to-init-file))'

7. Metals (Scala): install coursier with its JVM launcher. The native
   coursier binary does not run on Guix.

       mkdir -p ~/.local/bin
       curl -fL -o ~/.local/bin/cs https://raw.githubusercontent.com/coursier/launchers/master/coursier
       chmod +x ~/.local/bin/cs
       cs install metals

8. In Neovim, run `:UpdateRemotePlugins` once (for molten-nvim), then restart
   Neovim. Check the Python host with `:checkhealth provider`.


## G. Circular scrolling on the round touchpad

Put one finger on the rim of the pad and move it in a circle. Clockwise
scrolls down. This works like the Synaptics driver on Debian, with the same
ring (edges 1770, 5220, 1670, 4260) and speed (0.1 radian per step).

libinput, which Hyprland uses, has no circular scrolling for this pad. So
the `circscroll` service (circscroll.c) takes the real touchpad, makes a
virtual copy for Hyprland, and turns circles on the ring into scroll-wheel
events. A touch on the ring that moves inward, or a short tap, still goes to
Hyprland as normal, so the pointer and tap-to-click work there too. If
circscroll stops, the real touchpad works as before.

1. Apply it:

       sudo guix system reconfigure ~/dots/guix/panasonic/config.scm

   The service starts at once. You do not have to restart Hyprland.

2. Check it:

       sudo herd status circscroll
       sudo tail /var/log/circscroll.log

   The log must show `found "SynPS/2 Synaptics TouchPad"` and
   `virtual touchpad /dev/input/...`. If it shows `not found`, find the
   touchpad name with `grep Name /proc/bus/input/devices` and tell me.

3. To change the ring: stop the service, then let circscroll show where
   your touches land (Ctrl+C to stop), then start the service again:

       sudo herd stop circscroll
       sudo circscroll --print
       sudo herd start circscroll

   `--print` shows `RING` or `inside` for each touch. To try other values,
   run for example `sudo circscroll --edges 2000,4990,1840,4090 --verbose`
   (a wider ring) or `--step 0.15` (slower) while the service is stopped.
   When values feel right, add them in config.scm (see the comment above
   `%circscroll-service`) and reconfigure. `circscroll --help` lists all
   options.


## Later

    guix pull                                         # get new package versions
    sudo guix system reconfigure ~/dots/guix/panasonic/config.scm
    guix home reconfigure ~/dots/guix/panasonic/home.scm
    guix home roll-back                               # undo the last home change

To go back to an older system, select it in the GRUB menu at boot.

To find a program: `guix search NAME`. Add its name to home.scm and run
`guix home reconfigure` again.


## Known differences from Fedora

- Hyprland is 0.55.4. If your config uses an option that is new in 0.56,
  Hyprland shows an error at the top of the screen. The rest of the config
  still works.
- Circular scrolling comes from the circscroll service (section G), not from
  the touchpad driver. Two-finger scroll also works.
- hyprpaper runs through a small wrapper in home.scm (hyprpaper-with-mesa).
  Guix links hyprtoolkit to libglvnd's EGL, which has no driver on Guix, so
  hyprpaper alone stops with "eglGetProcAddress(eglCreateImageKHR) failed".
- If a key or a Waybar button does nothing, the program is probably not
  installed. Find it with `guix search NAME` and add it to home.scm.
- Japanese typing (not only the layout): Guix has fcitx5 with Anthy.
  Mozc is not in Guix.
- No Plymouth boot splash. Guix has the Plymouth program, but no service
  that runs it at boot, and the Guix initrd does not start it. config.scm
  uses `quiet loglevel=3` to show less text instead.
- oh-my-zsh does not update itself (the Guix copy is read-only). To update,
  change the commit in home.scm.
