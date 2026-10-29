;; config.scm -- Guix System for the Panasonic CF-SZ5 (Let's note)
;;
;; First install, from the live USB (see INSTALL.md):
;;   guix time-machine -C channels.scm -- system init config.scm /mnt
;; Later changes, on the installed system:
;;   sudo guix system reconfigure ~/dots/guix/config.scm
;;
;; Programs for your user are in home.scm, not here.

(use-modules (gnu)
             (guix build-system gnu)            ;circscroll
             (guix channels)
             ((guix licenses) #:prefix license:)
             (guix packages)
             (srfi srfi-1)                      ;remove
             ((gnu packages admin) #:select (tuigreet))
             ((gnu packages fonts) #:select (font-terminus))
             ((gnu packages linux) #:select (brightnessctl))
             ((gnu packages shells) #:select (zsh))
             ((gnu packages xdisorg) #:select (hyprlock))
             ((gnu packages xorg) #:select (libevdev))
             (nongnu packages linux)            ;full kernel and firmware
             (nongnu system linux-initrd)       ;CPU microcode
             (btv tailscale))                   ;tailscale channel
(use-service-modules desktop shepherd xorg)

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

;; Tailscale (tailscale and tailscaled, and tailscale-service-type).
;; Guix itself has no Tailscale package. The same lines are in
;; channels.scm. There is no build server: Guix builds it from source.
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

;; Circular scrolling on the round touchpad: move one finger around the rim
;; (like the Synaptics driver on Debian). libinput, which Hyprland uses, has
;; no circular scrolling for this pad, so circscroll.c (in this folder) does
;; it between the touchpad and libinput. It works with any compositor.
(define circscroll
  (package
    (name "circscroll")
    (version "0.1")
    (source (local-file "circscroll.c"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (copy-file source "circscroll.c")))
          (delete 'configure)
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "gcc" "-O2" "-Wall" "-o" "circscroll" "circscroll.c"
                      (string-append
                       "-I" (search-input-directory inputs
                                                    "include/libevdev-1.0"))
                      "-levdev" "-lm")))
          (replace 'install
            (lambda _
              (install-file "circscroll" (string-append #$output "/bin")))))))
    (inputs (list libevdev))
    (home-page "https://github.com/CalMy-2112/dotfiles")
    (synopsis "Circular scrolling for round touchpads")
    (description
     "circscroll turns a finger that moves around the rim of a round
touchpad into scroll-wheel events, for any Wayland compositor.")
    (license license:expat)))

;; The service runs as root at boot and restarts if it stops. Its messages
;; go to /var/log/circscroll.log. To change the ring or the speed, add
;; options after the program name, for example
;;   (list #$(file-append circscroll "/bin/circscroll") "--step" "0.15")
;; ("circscroll --help" lists them), then reconfigure.
(define %circscroll-service
  (simple-service
   'circscroll shepherd-root-service-type
   (list (shepherd-service
          (provision '(circscroll))
          (requirement '(udev))
          (documentation "Circular scrolling on the round touchpad.")
          (start #~(make-forkexec-constructor
                    (list #$(file-append circscroll "/bin/circscroll"))
                    #:log-file "/var/log/circscroll.log"))
          (stop #~(make-kill-destructor))
          (respawn? #t)))))

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

  ;; circscroll is here too, so you can run "sudo circscroll --print".
  ;; tailscale: the "tailscale" command (the service only runs tailscaled).
  (packages (cons* circscroll tailscale %base-packages))

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

    ;; Circular scrolling on the round touchpad (see circscroll above).
    %circscroll-service

    ;; Tailscale daemon (Shepherd service "tailscaled"). State is in
    ;; /var/lib/tailscale. Log in once with: sudo tailscale up
    (service tailscale-service-type)

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
