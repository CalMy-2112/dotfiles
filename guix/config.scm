;; config.scm -- Guix System for the Panasonic CF-SZ5 (Let's note)
;;
;; First install, from the live USB (see INSTALL.md):
;;   guix time-machine -C channels.scm -- system init config.scm /mnt
;; Later changes, on the installed system:
;;   sudo guix system reconfigure ~/dots/guix/config.scm
;;
;; Programs for your user are in home.scm, not here.

(use-modules (gnu)
             (guix channels)
             (srfi srfi-1)                      ;remove
             ((gnu packages admin) #:select (tuigreet))
             ((gnu packages fonts) #:select (font-terminus))
             ((gnu packages linux) #:select (brightnessctl))
             ((gnu packages shells) #:select (zsh))
             ((gnu packages xdisorg) #:select (hyprlock))
             (nongnu packages linux)            ;full kernel and firmware
             (nongnu system linux-initrd))      ;CPU microcode
(use-service-modules desktop xorg)

;; nonguix: the full Linux kernel and the firmware for the Intel 8260
;; Wi-Fi and Bluetooth. The same lines are in channels.scm.
(define %nonguix-channel
  (channel
   (name 'nonguix)
   (url "https://gitlab.com/nonguix/nonguix")
   (introduction
    (make-channel-introduction
     "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
     (openpgp-fingerprint
      "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))

;; Signing key of the nonguix build server. It must be the same as
;; https://substitutes.nonguix.org/signing-key.pub
(define %nonguix-key
  (plain-file
   "nonguix.pub"
   "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))

;; Disks. INSTALL.md makes the partitions with this label and this ID.
(define %root-fs
  (file-system
    (mount-point "/")
    (device (file-system-label "guix-root"))
    (type "ext4")))

(define %esp-fs
  (file-system
    (mount-point "/boot/efi")
    (device (uuid "1234-ABCD" 'fat))    ;made by: mkfs.fat -i 1234ABCD
    (type "vfat")))

;; Login screen: tuigreet, with the same options as on Debian.
;; After login it starts Hyprland. (--remember-session is not used:
;; there is only one session.)
(define %tuigreet
  (program-file
   "tuigreet-session"
   #~(execl #$(file-append tuigreet "/bin/tuigreet") "tuigreet"
            "--time" "--remember" "--asterisks"
            "--cmd" "start-hyprland")))

;; tuigreet keeps the last user name in /var/cache/tuigreet ("--remember").
;; The "greeter" user must be able to write there. This runs at every boot.
(define %tuigreet-cache
  (simple-service
   'tuigreet-cache activation-service-type
   (with-imported-modules '((guix build utils))
     #~(begin
         (use-modules (guix build utils))
         (let ((greeter (false-if-exception (getpwnam "greeter"))))
           (mkdir-p "/var/cache/tuigreet")
           (when greeter
             (chown "/var/cache/tuigreet"
                    (passwd:uid greeter) (passwd:gid greeter))))))))

;; Big console font for tuigreet and the text consoles (Terminus 16x32,
;; the same as on Debian). The 12.1" 1920x1200 screen makes 8x16 tiny.
(define %console-fonts
  (map (lambda (tty)
         (cons tty (file-append font-terminus "/share/consolefonts/ter-132n")))
       '("tty1" "tty2" "tty3" "tty4" "tty5" "tty6")))

;; tuigreet uses tty1, so remove the text login on tty1.
;; tty2 to tty6 keep the normal text login (Ctrl+Alt+F2).
(define (tty1-login? service)
  (and (eq? (service-kind service) mingetty-service-type)
       (string=? "tty1" (mingetty-configuration-tty (service-value service)))))

(operating-system
  (host-name "smol")
  (timezone "America/New_York")         ;your Debian clock showed EDT
  (locale "en_US.utf8")

  ;; Japanese (JIS) keyboard for the text console, tuigreet and GRUB.
  ;; Hyprland has its own setting: kb_layout in hyprland.lua.
  (keyboard-layout (keyboard-layout "jp" #:model "jp106"))

  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

  ;; Less text at boot: "quiet" is already in the defaults, loglevel=3 also
  ;; hides kernel warnings. Guix has no Plymouth, so this is the closest.
  (kernel-arguments (cons "loglevel=3" %default-kernel-arguments))

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets '("/boot/efi"))
               (keyboard-layout keyboard-layout)))

  (file-systems (cons* %root-fs %esp-fs %base-file-systems))

  ;; 4 GiB swap file. INSTALL.md makes it.
  (swap-devices (list (swap-space
                       (target "/swapfile")
                       (dependencies (list %root-fs)))))

  (users (cons (user-account
                (name "osho")
                (group "users")
                (home-directory "/home/osho")
                (shell (file-append zsh "/bin/zsh"))   ;like chsh on Debian
                (supplementary-groups '("wheel" "netdev" "audio" "video")))
               %base-user-accounts))

  (packages %base-packages)

  (services
   (cons*
    ;; Login screen on tty1.
    (service greetd-service-type
             (greetd-configuration
              (terminals
               (list (greetd-terminal-configuration
                      (terminal-vt "1")
                      (terminal-switch #t)
                      (default-session-command %tuigreet))))))
    %tuigreet-cache

    ;; hyprlock checks your password with the PAM file /etc/pam.d/hyprlock.
    ;; This service makes that file. (hyprlock itself is in home.scm.)
    (service screen-locker-service-type
             (screen-locker-configuration
              (name "hyprlock")
              (program (file-append hyprlock "/bin/hyprlock"))
              (using-pam? #t)
              (using-setuid? #f)))

    ;; Bluetooth (Waybar module, blueman).
    (service bluetooth-service-type
             (bluetooth-configuration (auto-enable? #t)))

    ;; Brightness keys without sudo (you are in the "video" group).
    (udev-rules-service 'brightnessctl brightnessctl)

    ;; %desktop-services: NetworkManager, elogind, D-Bus, polkit, udisks...
    (remove tty1-login?
            (modify-services %desktop-services
              ;; greetd replaces the GNOME login screen.
              (delete gdm-service-type)
              (console-font-service-type config => %console-fonts)
              (guix-service-type
               config => (guix-configuration
                          (inherit config)
                          ;; Write nonguix into /etc/guix/channels.scm, so
                          ;; that a plain "guix pull" gets it.
                          (channels (cons %nonguix-channel %default-channels))
                          ;; Download the kernel and firmware already built.
                          (substitute-urls
                           (append (guix-configuration-substitute-urls config)
                                   (list "https://substitutes.nonguix.org")))
                          (authorized-keys
                           (append (guix-configuration-authorized-keys config)
                                   (list %nonguix-key))))))))))
