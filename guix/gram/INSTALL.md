# Guix System on the LG gram 16 2-in-1 (16T90R): install steps

This replaces Fedora on the gram. **The install erases the internal disk.**
Do section A on Fedora first.

Files in this folder:

- `config.scm`: the system (kernel, Wi-Fi and sound firmware, disk, user
  calmy, Bluetooth, tuigreet login screen, zram, power profiles, Tailscale).
- `home.scm`: your programs and dotfiles (Hyprland, Waybar, swaync quick
  settings, night light, LibreOffice, Krita, Kdenlive, mpv, Electrum, Tor
  Browser, Wine, Steam, Flatpak for Zen, Neovim tools).
- `installer.scm`: the Guix installer with the full kernel from nonguix,
  so that the gram's Wi-Fi works in the installer. You build it on the
  Panasonic (A4).
- `../channels.scm`: Guix + nonguix + tailscale. The same file as for the
  Panasonic. Used only for the first install.

Differences from the Panasonic steps (`../INSTALL.md`):

- The gram has no Ethernet port, and the normal Guix installer has no
  driver for the gram's Wi-Fi. So you use a nonguix installer stick (A4),
  and connect to Wi-Fi in the installer (C).
- The disk is NVMe: the partitions are `nvme0n1p1` and `nvme0n1p2`.
- No swap file. zram (in config.scm) does the same as on Fedora.
- You do not copy or edit configs by hand. home.scm links `~/.config/hypr`,
  `waybar`, `fuzzel`, ... to `~/dots`, and `hypr/hyprland.lua` in the
  repository is already changed for Guix.


## A. On Fedora, before you erase

### A1. Put the new files in the repository

    cd ~/dots
    git am ~/Downloads/0001-guix-gram-config-for-the-LG-gram.patch
    git push

(Change the path to where you saved the patch.)

### A2. Optional: more files for the repository

- **qt6ct** (the look of Krita, Kdenlive and other Qt programs). home.scm
  links `~/.config/qt6ct` if the folder is in the repository:

      cp -r ~/.config/qt6ct ~/dots/
      grep -n /usr ~/dots/qt6ct/qt6ct.conf

  If grep shows a line with `/usr/share/qt6ct/...`, change `/usr` to
  `/home/calmy/.guix-home/profile` in that line. Guix has no `/usr/share`.

- **Scripts from `~/.local/bin`** that you want on the gram (for example
  `cast-start`, `cast-stop`, `tvplay`, `tv-audio`). Every file in `bin/`
  becomes a link in `~/.local/bin`:

      cp ~/.local/bin/{cast-start,cast-stop,tvplay,tv-audio} ~/dots/bin/

  These scripts can use Fedora programs. Send them to me if you want me to
  check them.

Then commit and push:

    cd ~/dots && git add -A && git commit -m "qt6ct and scripts" && git push

### A3. Back up what is not on the flash drive yet

The flash drive has Documents, Projects and .zen. Do these steps too.

1. Make sure that the archives on the flash drive are complete. Each line
   must start with `OK`:

       M=/run/media/calmy/main
       for f in "$M"/*.tar.gz "$M"/.zen.tar.gz; do
         tar -tzf "$f" >/dev/null && echo "OK  $f" || echo "BAD $f"
       done

2. Make sure that `.zen.tar.gz` has your real Zen profile. In Zen, open
   `about:profiles`. Look at the "Root Directory" of the profile that is in
   use.
   - If it is in `~/.zen`, the archive is correct. If you used Zen after
     you made it (31 Oct, 00:09), close Zen and make it again:

         tar -czf "$M/.zen.tar.gz" -C ~ .zen

   - If it is in `~/.config/zen`, the archive does not have your profile.
     Close Zen and make it from that folder:

         tar -czf "$M/.zen.tar.gz" -C ~/.config zen

   Section G finds the profile in either archive.

3. **CAUTION: your Bitcoin wallet is in `~/.electrum`. It is not on the
   flash drive yet.** Make sure that you have the seed words on paper
   (Electrum: Wallet > Seed). Then back up the wallet files with the other
   small things (SSH keys, GPG keys, git settings, your scripts):

       tar --ignore-failed-read -czf "$M/small-stuff.tar.gz" -C ~ \
         .electrum .ssh .gnupg .gitconfig .local/bin .config/qt6ct
       tar -tzf "$M/small-stuff.tar.gz" | cut -d/ -f1 | sort -u

   The last command must show `.electrum` and `.ssh`.

4. Look for other big folders that are not backed up (Pictures, Downloads,
   Videos, a Wine folder `~/.wine`, ...):

       du -sh ~/* ~/.[!.]* 2>/dev/null | sort -h | tail -25

   Back up the ones that you need in the same way. The flash drive is FAT32:
   one file can be 4 GiB maximum.

5. Not necessary: Steam games (they download again), Bitwarden, Telegram
   (they are in the cloud), Wi-Fi passwords (you type them again).

### A4. Make the nonguix installer stick (on the Panasonic)

The gram has no Ethernet port. Your Guix installer stick has no driver for
the gram's Wi-Fi. `installer.scm` makes a Guix installer with the full
kernel and firmware from nonguix. The Panasonic already runs that kernel,
so it builds the image without compiling.

Write the image to your old Guix installer stick. Do not use the backup
flash drive. Do A1 first, so that `installer.scm` is on GitHub.

1. On the Panasonic, get the files into a new folder. (Your `~/dots` on
   the Panasonic does not change.)

       git clone https://github.com/CalMy-2112/dotfiles /tmp/dots

   Do not run `guix pull` before the next steps. The Panasonic's present
   Guix has the kernel and firmware in its store already. A newer Guix can
   need a kernel that nonguix has not built yet. Then the kernel compiles,
   and that takes many hours.

2. Make sure that there is space. The image and its parts need about 6 GB:

       df -h /gnu

3. Build the image. This takes 10 to 40 minutes. It downloads the parts
   that are not on the Panasonic yet:

       ISO=$(guix system image --image-type=iso9660 /tmp/dots/guix/gram/installer.scm)
       echo $ISO

   The last line shows a file name like `/gnu/store/...-image.iso`.
   If you see `building` and then a name with `-linux-6` or `-linux-7` in
   it (the kernel), stop with Ctrl+C and tell me.

4. Put in the old Guix installer stick. Find it, and compare its size with
   the size of the image. The stick must be larger:

       lsblk -o NAME,SIZE,MODEL,TRAN
       ls -lh $ISO

   **CAUTION: on the Panasonic, `sda` is the internal disk (TRAN = sata).**
   The stick is the line with TRAN = usb, for example `sdb`. Change `sdX`
   to it. dd erases the disk that you name.

       sudo dd if=$ISO of=/dev/sdX bs=4M status=progress oflag=sync


## B. Boot the installer

1. Remove the backup flash drive. Put in the nonguix installer stick (A4).
2. Start the gram. Press F2 at the LG logo to open the setup utility.
   Find **Secure Boot** (usually on the Boot or Security page) and set it
   to **Disabled**. Guix's boot loader is not signed. Save and exit.
3. Press F10 at the LG logo. Select the USB stick.
4. When the installer menu shows, press Ctrl+Alt+F3. You get a root shell.
   The text is small on this screen. That is normal.
5. Make sure that the gram booted in UEFI mode. This command must list
   files:

       ls /sys/firmware/efi


## C. Network (Wi-Fi)

1. Make sure that you booted the nonguix stick:

       uname -r
       ip -br link

   `uname -r` must not end in `-gnu` (that is the normal Guix kernel, which
   has no Wi-Fi driver for the gram). `ip -br link` must show a line that
   starts with `wl`, for example `wlan0` or `wlp0s20f3`.

2. Connect to your Wi-Fi:

       connmanctl

   Then type these commands in connmanctl, one at a time:

       enable wifi
       scan wifi
       services
       agent on
       connect wifi_..._psk
       quit

   For `connect`, use the ID that `services` shows next to your network
   name. connmanctl asks for the password.

3. Make sure that the network works:

       ping -c 3 gnu.org

You can also connect on the network page of the installer menu (tty1), and
then go back to the root shell with Ctrl+Alt+F3.


## D. Disk

**CAUTION: these commands erase Fedora and all files on the internal disk.**

1. Find the internal disk. It is `nvme0n1` (953.9G):

       lsblk -o NAME,SIZE,MODEL,TRAN

2. Erase, partition and format:

       DISK=/dev/nvme0n1
       wipefs -a ${DISK}p1 ${DISK}p2 ${DISK}p3 $DISK
       parted -s -a optimal $DISK mklabel gpt \
         mkpart ESP fat32 1MiB 1025MiB set 1 esp on \
         mkpart root ext4 1025MiB 100%
       mkfs.fat -F32 -i 1234ABCD ${DISK}p1
       mkfs.ext4 -L guix-root ${DISK}p2

   config.scm finds the disks by the label `guix-root` and the ID
   `1234-ABCD`. Do not change one without the other.

3. Mount, and keep the installer's downloads on the disk:

       mount LABEL=guix-root /mnt
       mkdir -p /mnt/boot/efi
       mount ${DISK}p1 /mnt/boot/efi
       herd start cow-store /mnt

   No swap file is necessary: the gram has 32 GB of memory.


## E. Install

1. Get your files:

       guix shell git -- git clone https://github.com/CalMy-2112/dotfiles /mnt/root/dots
       mkdir -p /mnt/etc
       cp /mnt/root/dots/guix/gram/config.scm /mnt/etc/config.scm

2. Trust the nonguix build server, so that the kernel and firmware
   download ready-built. (The installer from A4 has the nonguix kernel, but
   it does not trust the nonguix build server yet.)

       wget -O /tmp/nonguix.pub https://substitutes.nonguix.org/signing-key.pub
       cat /tmp/nonguix.pub
       guix archive --authorize < /tmp/nonguix.pub

   The `q #...#` value in the output must be the same as in config.scm
   (C1FD53E5...EA98). If it is not, stop and tell me.

3. Install. This takes 30 to 90 minutes:

       mkdir -p /mnt/var/cache/install
       export XDG_CACHE_HOME=/mnt/var/cache/install
       guix time-machine -C /mnt/root/dots/guix/channels.scm -- \
         system init /mnt/etc/config.scm /mnt \
         --substitute-urls='https://ci.guix.gnu.org https://bordeaux.guix.gnu.org https://substitutes.nonguix.org'

   If you see `building ...-linux-6...` or `...-linux-7...` (the kernel),
   nonguix has no ready-built kernel for this Guix version yet. Compiling it
   takes hours. You can let it run, or stop it with Ctrl+C and run the same
   command again later. Tailscale always builds from source (some minutes).

4. Restart and remove the USB stick:

       reboot


## F. First boot

The tuigreet login screen shows on tty1. It starts Hyprland, and Hyprland
is not installed until step 4. So do steps 1 to 4 on the text login on tty2.

1. Press Ctrl+Alt+F2. Log in as `root`. The password is empty. Set the
   passwords, then log out:

       passwd
       passwd calmy
       exit

2. Log in as `calmy` at the same prompt. Do not use `su calmy`:
   NetworkManager (and later Hyprland) refuses, because you are not logged
   in at the laptop. Wi-Fi now works:

       nmcli device wifi connect "NETWORK NAME" --ask

3. Update Guix. The first time takes 10 to 30 minutes.
   /etc/guix/channels.scm already includes nonguix and tailscale.

       guix pull
       hash guix

4. Get your files and install your programs. This downloads many GB
   (LibreOffice, Kdenlive, Krita, Steam, Tor Browser), so it takes a long
   time:

       guix shell git -- git clone https://github.com/CalMy-2112/dotfiles ~/dots
       guix home reconfigure ~/dots/guix/gram/home.scm

   Read the first lines of the output:
   - `home.scm: Hyprland 0.55.x (reads hyprland.lua)` is correct.
   - `home.scm: Guix has no package "NAME"; skipped` means that one program
     was not installed. The rest continues. Tell me the names.

   Guix Home moves old files that it replaces to a backup folder in your
   home. That is normal.

5. Log out (`exit`). Press Ctrl+Alt+F1 and log in at tuigreet. Hyprland
   starts. On tty2 (Ctrl+Alt+F2) you always get a text login. Use it if
   Hyprland does not start.

6. Delete the installer's download folder:

       sudo rm -rf /var/cache/install


## G. Restore your files

1. Put in the backup flash drive. udiskie mounts it and shows a
   notification. Find where:

       lsblk -o NAME,SIZE,LABEL,MOUNTPOINTS

   Set M to the mount point, for example:

       M=/media/calmy/main

2. Documents and Projects. First look at how the archive starts:

       tar -tzf "$M/Documents.tar.gz" | head -3

   - If the lines start with `Documents/`: `tar -xzf "$M/Documents.tar.gz" -C ~`
   - If they start with `home/calmy/`: `tar -xzf "$M/Documents.tar.gz" -C /`

   Do the same for `Projects.tar.gz`.

3. Electrum wallet, SSH keys, GPG keys, git settings:

       mkdir -p ~/restore
       tar -xzf "$M/small-stuff.tar.gz" -C ~/restore
       cp -a ~/restore/.electrum ~/restore/.ssh ~/
       cp -a ~/restore/.gnupg ~/ 2>/dev/null
       cp -a ~/restore/.gitconfig ~/ 2>/dev/null

   Do not copy `~/restore/.local/bin` to `~/.local/bin`: Guix Home makes
   that folder from `~/dots/bin`. The old scripts stay in
   `~/restore/.local/bin` for you to look at.

   Start `electrum`. It must show your wallet. Then you can delete
   `~/restore`.

4. Zen. Guix has no Zen package, so it comes from Flathub:

       flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
       flatpak install --user flathub app.zen_browser.zen
       flatpak run app.zen_browser.zen

   Close Zen when the window shows. Now put your old profile in:

       Z=~/.var/app/app.zen_browser.zen
       ls -a $Z $Z/config 2>/dev/null
       mkdir -p ~/restore-zen
       tar -xzf "$M/.zen.tar.gz" -C ~/restore-zen
       OLD=$(dirname "$(find ~/restore-zen -name profiles.ini | head -1)")
       echo $OLD

   The `ls` shows the folder that Zen made: `.zen` in $Z, or `zen` in
   `$Z/config`. Set NEW to it, then replace it with your old one:

       NEW=$Z/.zen            # or: NEW=$Z/config/zen
       mv "$NEW" "$NEW.empty"
       cp -a "$OLD" "$NEW"
       flatpak run app.zen_browser.zen

   If Zen shows no old tabs, open `about:profiles`, find your old profile,
   click "Set as default profile" and start Zen again. When all is
   correct, delete `~/restore-zen` and `$NEW.empty`.

   Zen shows in fuzzel after the next login. To update Zen:
   `flatpak update`.


## H. Other programs

- **Steam:** run `steam`. The first start downloads Steam itself. Steam
  runs in a container. Games go in `~/.local/share/guix-sandbox-home`.
- **Wine:** run `winecfg` once. It makes `~/.wine`. If you backed up an
  old `~/.wine`, restore it before that. Guix has no winetricks package.
- **Tor Browser:** the command is `torbrowser`.
- **LibreOffice, Krita, Kdenlive, mpv, Electrum:** start them from fuzzel
  (Super+D).
- **Tailscale:** `sudo tailscale up`, then open the link that it shows.
- **Neovim tools that are not in Guix** (pyright, bashls, ts_ls, asm-lsp,
  swank, metals, molten): do steps F5 to F8 in `../INSTALL.md`. They are
  the same on the gram.


## I. Check the gram

Do these checks once. Tell me which ones fail.

1. **Speakers.** Play a video or song. You said that the speakers work on
   Fedora (kernel 7.2.13), so the kernel has the fix for this model. If
   there is no sound from the speakers:

       uname -r
       cat /proc/asound/cards

2. **Quick settings.** Super+S opens the swaync panel. Try Wi-Fi,
   Bluetooth, Night Light, the sliders, Networks, Devices, Settings.
   Also check:

       swaync --version

   Your style.css uses CSS variables (`--cc-bg`, ...). Only swaync 0.12 or
   later reads them. If the version is older, the panel colors are partly
   wrong. Tell me the version.

3. **Night light.** Super+N, and the moon or sun icon in Waybar.
4. **Brightness keys** and the keyboard backlight slider.
5. **zram:** `swapon --show` shows `/dev/zram0` with 8G.
6. **Power profiles:** `powerprofilesctl` shows `balanced`.
7. **Touchscreen and pen:** draw in Krita.
8. **Suspend:** close the lid, open it. hyprlock must ask for your
   password.


## J. If something does not work

- **No Wi-Fi in the installer** (`uname -r` ends in `-gnu`, or no `wl...`
  line): you booted the old Guix stick. Do A4 again, and check that dd
  wrote to the stick.
- **"No bootable device" after the install:** press F10 at the LG logo and
  select the Guix entry. To remove Fedora's old boot entry:

      sudo guix shell efibootmgr -- efibootmgr
      sudo guix shell efibootmgr -- efibootmgr -b NNNN -B

  (NNNN is the number of the Fedora line.)
- **Hyprland does not start at tuigreet:** press Ctrl+Alt+F2, log in, and
  run `start-hyprland` there. The error shows in the terminal.
- **A swaync button does nothing:** run its command (in
  `~/dots/swaync/config.json`) in a terminal. The error shows there.
- **A key or a Waybar click does nothing:** the program is probably not
  installed. Find it with `guix search NAME`, add it to home.scm and run
  `guix home reconfigure` again.
- To go back to an older system, select it in the GRUB menu at boot.
  To undo the last home change: `guix home roll-back`.


## Later

    guix pull                                              # new package versions
    sudo guix system reconfigure ~/dots/guix/gram/config.scm
    guix home reconfigure ~/dots/guix/gram/home.scm
    flatpak update                                         # Zen

Your configs in `~/.config` (hypr, waybar, fuzzel, alacritty, fastfetch,
yazi, helix, nvim, swaync/config.json) are links to `~/dots`. Edit them
there, then commit and push from `~/dots`. Two exceptions:

- `swaync/style.css` is a copy (see `%swaync-style` in home.scm). After you
  edit `~/dots/swaync/style.css`, run `guix home reconfigure` again.
- `.zshrc` and `.tmux.conf.local` are copies too. Run `guix home
  reconfigure` after you edit them in `~/dots`.


## Known differences from Fedora

- Hyprland is the Guix version (0.55.x), not 0.57. hyprland.lua is for
  0.55, so it works.
- Zen is a Flatpak. It updates with `flatpak update`, not with Guix.
- Steam runs in a container. Its games are in
  `~/.local/share/guix-sandbox-home`, not in `~/.local/share/Steam`.
- Not in this config (Fedora had them): winetricks (Guix has no package),
  Docker, Telegram. Tell me if you want them.
- No systemd. Use `loginctl` (suspend, reboot, poweroff) and
  `sudo herd status` for services.
- hyprpaper runs through a small wrapper in home.scm, the same as on the
  Panasonic (a Guix EGL problem).
