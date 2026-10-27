;; home.scm -- programs and user services for osho (Guix Home)
;;
;;   guix home reconfigure ~/dots/guix/home.scm
;;
;; Your config files (hypr, waybar, fuzzel, alacritty, fastfetch, yazi)
;; are not managed here. Copy them from GitHub into ~/.config.
;; To add a program: add its name below and run the command again.
;; To find a name: guix search WORD

(use-modules (gnu home)
             (gnu home services)
             (gnu home services desktop)   ;D-Bus
             (gnu home services shells)    ;bash
             (gnu home services sound)     ;PipeWire
             (gnu packages)
             (gnu services)
             (guix gexp)
             (guix packages)
             (guix utils))

(define %my-packages
  '(;; Hyprland and its tools
    "hyprland" "hyprlock" "hypridle" "hyprpaper" "hyprsunset"
    "hyprpolkitagent"
    "xdg-desktop-portal" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "waybar" "fuzzel" "swaynotificationcenter" "libnotify"
    "grim" "slurp" "swappy" "wl-clipboard"
    "dbus" "xdg-utils" "qt6ct"
    ;; gsettings, for the dark GTK theme line in your Hyprland config
    "glib:bin" "gsettings-desktop-schemas" "dconf"

    ;; Waybar modules and their click actions: sound, brightness, media,
    ;; network (nm-connection-editor), Bluetooth (blueman, bluetoothctl)
    "pipewire" "wireplumber" "pavucontrol"
    "brightnessctl" "playerctl"
    "network-manager-applet" "blueman" "bluez"

    ;; Programs
    "librewolf" "alacritty" "btop" "tmux" "neovim"
    "yazi" "fastfetch" "git"

    ;; Tools that LazyVim (your Neovim config) needs. Delete if not used.
    "ripgrep" "fd" "gcc-toolchain" "make" "unzip"

    ;; Fonts and icons. Noto Sans CJK shows Japanese text.
    "font-nerd-jetbrains-mono" "font-google-noto" "font-google-noto-emoji"
    "font-google-noto-sans-cjk" "adwaita-icon-theme" "hicolor-icon-theme"))

;; Your hyprland.lua needs Hyprland 0.55 or later. Print the version.
(let ((version (package-version (specification->package "hyprland"))))
  (format (current-error-port) "home.scm: Hyprland ~a~a~%" version
          (if (version>=? version "0.55")
              " (reads hyprland.lua)"
              " -- OLDER THAN 0.55, it does not read hyprland.lua")))

(home-environment
 (packages (specifications->packages %my-packages))
 (services
  (list
   ;; Session D-Bus. PipeWire, the portals and notifications need it.
   (service home-dbus-service-type)
   ;; PipeWire + WirePlumber, with PulseAudio support (Waybar sound module).
   (service home-pipewire-service-type)
   ;; Start Hyprland when you log in on tty1. Other ttys stay text consoles.
   (service home-bash-service-type
            (home-bash-configuration
             (bash-profile
              (list (plain-file "start-hyprland" "\
if [ -z \"$WAYLAND_DISPLAY\" ] && [ \"$(tty)\" = /dev/tty1 ]; then
  if command -v start-hyprland >/dev/null; then
    exec start-hyprland
  else
    exec Hyprland
  fi
fi
"))))))))
