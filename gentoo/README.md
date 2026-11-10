# Gentoo config (omen)

This folder has the configs for the Gentoo laptop (HP Omen, user calmy).
The theme is "night-train". Its colors come from the wallpaper
`wallpapers/hyprland-girl.jpg`.

The Guix laptops do not use this folder. They use the top folders of the
repository (hypr/, waybar/, ...) with the Gruvbox colors. This folder does
not change those files.

    gentoo/
      install.sh        links the files into ~/.config (with a backup)
      config/           the same layout as ~/.config
        hypr/             hyprland.lua, hyprlock, hypridle, hyprpaper, scripts/
        waybar/           bar
        swaync/           notifications and quick settings (Super+S)
        fuzzel/           app launcher (Super+D)
        alacritty/        terminal, night-train.toml has the 16 colors
        yazi/             file manager
        btop/themes/      night-train.theme
        fastfetch/        system information
        gtk-3.0/          GTK 3 programs (pavucontrol, blueman, ...)
        gtk-4.0/          GTK 4 and libadwaita (GNOME) programs
        qt6ct/            Qt 6 programs (Electrum, ...)

## Install

1. Install the packages (see the list below).
2. Clone the repository, for example to ~/dots.
3. Close btop if it runs.
4. See what the script will do:

       sh ~/dots/gentoo/install.sh -n

5. Do it:

       sh ~/dots/gentoo/install.sh

6. Log out of Hyprland (Super+Shift+E) and log in again.

The script moves each old file to `~/.dots-backup/<date>/` before it makes
the link. To compare your old Hyprland config with the new one, use:

    diff ~/.dots-backup/<date>/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua

The links point into the repository. When you edit a file in ~/.config,
you edit the repository file. Use `git diff` to see the changes.

## Packages

These are the packages from `hyprland-config-gentoo-port` (project notes)
and the new packages for the theme.

Theme packages (new):

| Package | Repository | Used for |
|---|---|---|
| x11-themes/adw-gtk3 | ::guru | GTK 3 theme that reads gtk-3.0/gtk.css |
| x11-themes/papirus-icon-theme | ::gentoo | Papirus-Dark icons |
| gui-apps/qt6ct | ::gentoo | Qt 6 colors |
| sys-apps/xdg-desktop-portal-gtk | ::gentoo | gives "prefer-dark" to libadwaita, Electron and Zen |
| gnome-base/dconf | ::gentoo | stores the gsettings values |
| media-fonts/nerdfonts (USE=jetbrainsmono) | ::guru | JetBrainsMono Nerd Font |

Other packages that the configs use:

- ::gentoo: gui-apps/waybar, x11-terms/alacritty, sys-process/btop,
  app-misc/fastfetch
- ::guru: gui-apps/swaync, gui-apps/fuzzel, app-misc/yazi,
  gui-apps/wlsunset, x11-themes/phinger-cursors
- ::hyproverlay: gui-apps/hyprlock, gui-apps/hypridle, gui-apps/hyprpaper

If adw-gtk3 or Papirus is not installed, `hypr/scripts/dark-theme.sh` uses
Adwaita. The programs are then dark, but with gray colors.

## Palette

| Name | Color | Used for |
|---|---|---|
| crust | `#0b0620` | shadows |
| mantle | `#0e0726` | bar, lists (GTK "view"), text on cyan |
| base | `#140b33` | window and terminal background |
| surface0 | `#1e1548` | modules, header bars, menus |
| surface1 | `#2a2160` | hover |
| surface2 | `#3a3380` | borders |
| indigo | `#2b3786` | text selection, inactive window border |
| overlay | `#6f6aa8` | muted text |
| subtext | `#aaa6d6` | secondary text |
| text | `#e4e0f7` | main text |
| cyan | `#47aeda` | accent: active workspace, buttons, links |
| glow | `#7fd8f2` | bright accent, cursor |
| sky | `#6f97e6` | blue text |
| lavender | `#ba94c3` | second accent, window border gradient |
| plum | `#642c5f` | btop graphs |
| pink | `#e48ab8` | today in the calendar |
| red | `#f0647f` | errors, critical battery |
| orange | `#f2a272` | warnings, Caps Lock on the lock screen |
| yellow | `#f2cf8a` | night light on |
| green | `#66d9a8` | terminal green, success |

All text colors have a contrast of 4.5:1 or more on base.
The main text has 14.5:1.

## How each program gets the dark theme

- GTK 3: `dark-theme.sh` sets the gsettings key `gtk-theme` to
  `adw-gtk3-dark`. adw-gtk3 reads the colors in `gtk-3.0/gtk.css`.
  `gtk-3.0/settings.ini` is for programs in XWayland.
- GTK 4 and libadwaita (GNOME programs): `dark-theme.sh` sets
  `color-scheme` to `prefer-dark`. GTK 4 loads `gtk-4.0/gtk.css` last, so
  its colors replace the gray Adwaita colors.
- Qt 6: hyprland.lua sets `QT_QPA_PLATFORMTHEME=qt6ct`. qt6ct reads
  `qt6ct/colors/night-train.conf`.
- Electrum 4.6 and later use Qt 6. Keep "Color theme" in the Electrum
  preferences at "default". Then Electrum uses the qt6ct colors. The "dark"
  setting of Electrum uses its own gray colors.
- Electron programs (Bitwarden) and Zen: they read `prefer-dark` from the
  portal (xdg-desktop-portal-gtk).

hyprland.lua does not set `GTK_THEME`. That variable also changes
libadwaita programs and breaks their colors. If a GTK 3 program stays
light, remove the `--` in front of the `GTK_THEME` line in hyprland.lua.

## Check after the first login

- Brightness slider in swaync (Super+S): the config uses `amdgpu_bl1` and
  `hp::kbd_backlight`. If a slider is not there, the name is not correct.
  Run `ls /sys/class/backlight /sys/class/leds` and change the `device`
  values in `config/swaync/config.json`. The waybar module finds the
  device itself.
- Monitors: hyprland.lua has `eDP-1` and the Sceptre F22, both at
  1920x1080@144. Run `hyprctl monitors` to see the real names and modes.
- btop: if btop shows the old colors, close btop and run install.sh again.
