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
             ((gnu packages linux) #:select (brightnessctl))
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

(operating-system
  (host-name "smol")
  (timezone "America/New_York")         ;your Debian clock showed EDT
  (locale "en_US.utf8")

  ;; Japanese (JIS) keyboard for the text console and GRUB.
  ;; Hyprland has its own setting: kb_layout in hyprland.lua.
  (keyboard-layout (keyboard-layout "jp" #:model "jp106"))

  (kernel linux)
  (initrd microcode-initrd)
  (firmware (list linux-firmware))

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
                (supplementary-groups '("wheel" "netdev" "audio" "video")))
               %base-user-accounts))

  (packages %base-packages)

  (services
   (cons*
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
    (modify-services %desktop-services
      ;; No login screen. You log in on tty1 and Hyprland starts.
      (delete gdm-service-type)
      (guix-service-type
       config => (guix-configuration
                  (inherit config)
                  ;; Write nonguix into /etc/guix/channels.scm, so that a
                  ;; plain "guix pull" gets it.
                  (channels (cons %nonguix-channel %default-channels))
                  ;; Download the kernel and firmware already built.
                  (substitute-urls
                   (append (guix-configuration-substitute-urls config)
                           (list "https://substitutes.nonguix.org")))
                  (authorized-keys
                   (append (guix-configuration-authorized-keys config)
                           (list %nonguix-key)))))))))
