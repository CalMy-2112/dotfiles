;; channels.scm -- Guix plus nonguix (full Linux kernel and firmware).
;;
;; On the installed system, copy it to ~/.config/guix/channels.scm,
;; then run: guix pull
;;
;; The introduction lines make guix pull check the nonguix signatures.
;; They are from the nonguix README.

(cons* (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
       %default-channels)
