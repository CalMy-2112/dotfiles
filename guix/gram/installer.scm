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
             (nongnu packages linux)    ;linux, linux-firmware
             (srfi srfi-1))             ;remove

(operating-system
  (inherit installation-os)
  (kernel linux)
  (firmware (list linux-firmware))

  ;; Remove the gc-root service. In the normal installer it keeps a copy of
  ;; the "bare-bones" example system, so that installing that example
  ;; downloads less. In Guix of October 2026 (commit 9cc4f49) that copy does
  ;; not build: the example uses the new "transformation" field (tune for
  ;; skylake), and the copy fails with
  ;;   etc points to inexistent file or dangling symlink /gnu/store/...-etc
  ;; Your install does not use the example, so nothing is lost.
  (services
   (remove (lambda (service)
             (eq? (service-kind service) gc-root-service-type))
           (operating-system-user-services installation-os))))
