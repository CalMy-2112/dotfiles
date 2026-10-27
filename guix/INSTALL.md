# Guix System on the CF-SZ5: install steps

Files in this folder:

- `config.scm`: the system (kernel, Wi-Fi firmware, disks, user, Bluetooth, JP keyboard).
- `home.scm`: your programs and user services (Hyprland, Waybar, PipeWire...).
- `channels.scm`: Guix + nonguix. Used only for the first install.

Change `YOU/DOTS` below to your GitHub repository. These steps expect this
folder to be at `guix/` in that repository.

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
       cp /mnt/root/dots/guix/config.scm /mnt/etc/config.scm

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

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!HERE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
4. Restart and remove the USB stick:

       reboot


## E. First boot

1. At the login prompt, log in as `root`. The password is empty.
   Set the passwords, then log out:

       passwd
       passwd osho
       exit

2. Log in as `osho`. Wi-Fi now works:

       nmcli device wifi connect "NETWORK NAME" --ask

3. Update Guix. The first time takes 10 to 30 minutes.
   /etc/guix/channels.scm already includes nonguix.

       guix pull
       hash guix

4. Get your files and install your programs:

       guix shell git -- git clone https://github.com/YOU/DOTS ~/dots
       guix home reconfigure ~/dots/guix/home.scm

   This prints `home.scm: Hyprland 0.55.x (reads hyprland.lua)`.
   Guix Home moves the old ~/.bash_profile and ~/.bashrc to a backup folder.
   That is normal.

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

8. Cursor: Guix does not have phinger-cursors. Install it like on Debian:

       mkdir -p ~/.local/share/icons
       guix shell curl -- curl -L -o /tmp/phinger.tar.bz2 https://github.com/phisch/phinger-cursors/releases/latest/download/phinger-cursors-variants.tar.bz2
       tar -xjf /tmp/phinger.tar.bz2 -C ~/.local/share/icons

9. Log out (`exit`) and log in on tty1. Hyprland starts.
   On tty2 (Ctrl+Alt+F2) you always get a text login. Use it if Hyprland
   does not start.

10. Delete the installer's download folder:

        sudo rm -rf /var/cache/install


## Later

    guix pull                                         # get new package versions
    sudo guix system reconfigure ~/dots/guix/config.scm
    guix home reconfigure ~/dots/guix/home.scm
    guix home roll-back                               # undo the last home change

To go back to an older system, select it in the GRUB menu at boot.

To find a program: `guix search NAME`. Add its name to home.scm and run
`guix home reconfigure` again.


## Known differences from Fedora

- Hyprland is 0.55.4. If your config uses an option that is new in 0.56,
  Hyprland shows an error at the top of the screen. The rest of the config
  still works.
- Circular scrolling on the round touchpad does not work in Hyprland
  (libinput does not support it for this model). Two-finger scroll works.
- If a key or a Waybar button does nothing, the program is probably not
  installed. Find it with `guix search NAME` and add it to home.scm.
- Japanese typing (not only the layout): Guix has fcitx5 with Anthy.
  Mozc is not in Guix.
