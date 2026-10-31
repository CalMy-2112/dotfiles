;; config.scm -- Guix System for the LG gram 16 2-in-1 (16T90R-K.ADB9U1)
;;
;; Made from ../panasonic/config.scm. Changes for the gram:
;;   - NVMe disk (nvme0n1p1, nvme0n1p2), no swap file: zram, like Fedora
;;   - US keyboard, no circscroll (the gram has a normal touchpad)
;;   - user calmy, host calmySchool (the same as on Fedora)
;;   - Sound Open Firmware (the gram's Intel audio needs it)
;;   - power-profiles-daemon (Fedora had tuned-ppd)
;;   - udev rules: Steam controllers, rfkill for the swaync Bluetooth button
;;
;; First install, from the live USB (see INSTALL.md in this folder):
;;   guix time-machine -C ../channels.scm -- system init config.scm /mnt
;; Later changes, on the installed system:
;;   sudo guix system reconfigure ~/dots/guix/gram/config.scm
;;
;; Programs for your user are in home.scm, not here.

(use-modules (gnu)
             (guix channels)
             (srfi srfi-1)                      ;find, remove
             ((gnu packages admin) #:select (tuigreet))
             ((gnu packages fonts) #:select (font-terminus))
             ((gnu packages linux) #:select (brightnessctl))
             ((gnu packages shells) #:select (zsh))
             ((gnu packages xdisorg) #:select (hyprlock))
             (nongnu packages linux)            ;full kernel and firmware
             (nongnu system linux-initrd)       ;CPU microcode
             (btv tailscale))                   ;tailscale channel
(use-service-modules desktop linux pm xorg)

;; nonguix: the full Linux kernel and the firmware for the Intel Wi-Fi,
;; Bluetooth, GPU and audio. The same lines are in ../channels.scm.
(define %nonguix-channel
  (channel
   (name 'nonguix)
   (url "https://gitlab.com/nonguix/nonguix")
   (introduction
    (make-channel-introduction
     "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
     (openpgp-fingerprint
      "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))

;; Tailscale (Fedora had it too). The same lines are in ../channels.scm.
;; There is no build server: Guix builds it from source.
(define %tailscale-channel
  (channel
   (name 'tailscale)
   (url "https://github.com/umanwizard/guix-tailscale")
   (branch "main")
   (introduction
    (make-channel-introduction
     "52e82318f282c555757ef077d93a685fda97565d"
     (openpgp-fingerprint
      "9E53FC33B8328C745E7B31F70226C10D7877B741")))))

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

;; Login screen: tuigreet, the same as on the Panasonic.
;; After login it starts Hyprland.
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

;; Big console font for tuigreet and the text consoles (Terminus 16x32).
;; The 16" 2560x1600 screen makes the normal 8x16 font very small.
(define %console-fonts
  (map (lambda (tty)
         (cons tty (file-append font-terminus "/share/consolefonts/ter-132n")))
       '("tty1" "tty2" "tty3" "tty4" "tty5" "tty6")))

;; The Bluetooth button in the swaync panel runs "rfkill unblock bluetooth"
;; as your user. Let the "netdev" group (you) use /dev/rfkill.
(define %rfkill-rule
  (udev-rule "90-rfkill-netdev.rules"
             "KERNEL==\"rfkill\", GROUP=\"netdev\", MODE=\"0664\"\n"))

;; power-profiles-daemon (balanced / power-saver / performance, also in
;; GNOME Settings > Power). Added only if %desktop-services does not already
;; have it, because a service type two times is an error.
(define %power-profiles
  (if (find (lambda (service)
              (eq? (service-kind service) power-profiles-daemon-service-type))
            %desktop-services)
      '()
      (list (service power-profiles-daemon-service-type))))

;; tuigreet uses tty1, so remove the text login on tty1.
;; tty2 to tty6 keep the normal text login (Ctrl+Alt+F2).
(define (tty1-login? service)
  (and (eq? (service-kind service) mingetty-service-type)
       (string=? "tty1" (mingetty-configuration-tty (service-value service)))))

(operating-system
  (host-name "calmySchool")
  (timezone "America/New_York")
  (locale "en_US.utf8")

  (keyboard-layout (keyboard-layout "us"))

  (kernel linux)
  (initrd microcode-initrd)
  ;; sof-firmware: the gram's sound card (Intel Raptor Lake, SOF driver).
  ;; Fedora has the same files in alsa-sof-firmware.
  ;; specification->package finds it in whichever nonguix module has it.
  (firmware (list linux-firmware
                  (specification->package "sof-firmware")))

  ;; Less text at boot: "quiet" is already in the defaults, loglevel=3 also
  ;; hides kernel warnings.
  (kernel-arguments (cons "loglevel=3" %default-kernel-arguments))

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (targets '("/boot/efi"))
               (keyboard-layout keyboard-layout)))

  (file-systems (cons* %root-fs %esp-fs %base-file-systems))

  (users (cons (user-account
                (name "calmy")
                (group "users")
                (home-directory "/home/calmy")
                (shell (file-append zsh "/bin/zsh"))
                (supplementary-groups '("wheel" "netdev" "audio" "video")))
               %base-user-accounts))

  ;; tailscale: the "tailscale" command (the service only runs tailscaled).
  (packages (cons* tailscale %base-packages))

  (services
   (append
    (list
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

     ;; Bluetooth (Waybar module, swaync button, blueman).
     (service bluetooth-service-type
              (bluetooth-configuration (auto-enable? #t)))

     ;; Brightness keys and the swaync slider without sudo ("video" group).
     (udev-rules-service 'brightnessctl brightnessctl)

     ;; Steam controllers and other game pads (Fedora: steam-devices).
     (udev-rules-service 'steam-devices
                         (specification->package "steam-devices-udev-rules"))

     ;; swaync Bluetooth button (see %rfkill-rule above).
     (udev-rules-service 'rfkill-netdev %rfkill-rule)

     ;; Compressed swap in RAM, like Fedora's zram0 (8 GiB). No swap file.
     (service zram-device-service-type
              (zram-device-configuration
               (size "8G")
               (compression-algorithm 'zstd)))

     ;; Tailscale daemon (Shepherd service "tailscaled"). State is in
     ;; /var/lib/tailscale. Log in once with: sudo tailscale up
     (service tailscale-service-type))

    %power-profiles

    ;; %desktop-services: NetworkManager, elogind, D-Bus, polkit, udisks...
    (remove tty1-login?
            (modify-services %desktop-services
              ;; greetd replaces the GNOME login screen.
              (delete gdm-service-type)
              (console-font-service-type config => %console-fonts)
              (guix-service-type
               config => (guix-configuration
                          (inherit config)
                          ;; Write nonguix and tailscale into
                          ;; /etc/guix/channels.scm, so that a plain
                          ;; "guix pull" gets them.
                          (channels (cons* %tailscale-channel
                                           %nonguix-channel
                                           %default-channels))
                          ;; Download the kernel and firmware already built.
                          (substitute-urls
                           (append (guix-configuration-substitute-urls config)
                                   (list "https://substitutes.nonguix.org")))
                          (authorized-keys
                           (append (guix-configuration-authorized-keys config)
                                   (list %nonguix-key))))))))))
