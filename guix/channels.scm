;; channels.scm -- Guix plus nonguix (full Linux kernel and firmware)
;; plus tailscale.
;;
;; On the installed system, copy it to ~/.config/guix/channels.scm,
;; then run: guix pull
;;
;; The introduction lines make guix pull check the channel signatures.
;; They are from the nonguix README and the guix-tailscale README.

(cons* (channel
        (name 'tailscale)
        (url "https://github.com/umanwizard/guix-tailscale")
        (branch "main")
        (introduction
         (make-channel-introduction
          "52e82318f282c555757ef077d93a685fda97565d"
          (openpgp-fingerprint
           "9E53FC33B8328C745E7B31F70226C10D7877B741"))))
       (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
       %default-channels)
