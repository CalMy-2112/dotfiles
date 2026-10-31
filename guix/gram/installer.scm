;; installer.scm -- the Guix installer, with the full Linux kernel and
;; firmware from nonguix, so that the gram's Wi-Fi works in the installer.
;;
;; Build it on the Panasonic (Guix with nonguix), see INSTALL.md, A4:
;;   guix system image --image-type=iso9660 ~/dots/guix/gram/installer.scm
;;
;; This is smaller than nonguix's own nongnu/system/install.scm: that file
;; also builds Guix with nonguix inside the image, which can compile for
;; hours. The install (INSTALL.md, E3) gets nonguix with "guix time-machine",
;; so the installer does not need it.

(use-modules (gnu)
             (gnu system install)       ;installation-os
             (nongnu packages linux))   ;linux, linux-firmware

(operating-system
  (inherit installation-os)
  (kernel linux)
  (firmware (list linux-firmware)))
