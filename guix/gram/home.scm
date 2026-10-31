;; home.scm -- programs, dotfiles and user services for calmy on the
;; LG gram (Guix Home)
;;
;;   guix home reconfigure ~/dots/guix/gram/home.scm
;;
;; Made from ../panasonic/home.scm. This file is in guix/gram/ of your
;; dotfiles repository (~/dots). It uses these repository files, if they are
;; there:
;;   zsh/.zshrc               -> ~/.config/zsh/.zshrc
;;   tmux/.tmux.conf.local    -> ~/.tmux.conf.local
;;   swaync/config.json       -> ~/.config/swaync/config.json (a link)
;;   swaync/style.css         -> ~/.config/swaync/style.css (changed for Guix,
;;                               see %swaync-style)
;;   bin/*                    -> ~/.local/bin/* (links, so they stay editable)
;;   hypr/, waybar/, nvim/... -> ~/.config/... (links, see %linked-configs)
;;
;; To add a program: add its name below and run the command again.
;; To find a name: guix search WORD

(use-modules (gnu home)
             (gnu home services)
             (gnu home services desktop)   ;D-Bus
             (gnu home services shells)    ;zsh
             (gnu home services sound)     ;PipeWire
             (gnu packages)
             ((gnu packages base) #:select (glibc))
             ((gnu packages bash) #:select (bash-minimal))
             ((gnu packages elf) #:select (patchelf))
             ((gnu packages gcc) #:select (gcc))
             ((gnu packages gl) #:select (mesa))
             ((gnu packages python) #:select (python))
             ((gnu packages xdisorg) #:select (hyprpaper))
             (gnu services)
             (guix build-system copy)
             (guix build-system font)
             (guix build-system trivial)
             (guix download)
             (guix gexp)
             (guix git-download)
             ((guix licenses) #:prefix license:)
             (guix packages)
             (guix utils)
             (ice-9 ftw)                   ;scandir
             (srfi srfi-1))                ;filter-map

;;;
;;; The dotfiles repository
;;;

;; Two folders above this file (guix/gram/): /home/calmy/dots.
(define %dots (dirname (dirname (current-source-directory))))

;; A file from the repository, or #f (with a note) if it is not there yet.
(define (dots-file name relative)
  (let ((file (string-append %dots "/" relative)))
    (if (file-exists? file)
        (local-file (assume-valid-file-name file) name)
        (begin
          (format (current-error-port)
                  "home.scm: ~a is not in the repository yet; skipped~%"
                  relative)
          #f))))

;; A link to a file or folder in the repository. The files are not copied
;; to the store, so you can edit them (and lazy.nvim can write
;; lazy-lock.json).
(define (dots-link relative)
  (computed-file (string-append (basename relative) "-link")
                 #~(symlink #$(string-append %dots "/" relative) #$output)))

;; Folders in ~/.config that are links to the repository. hypr/hyprland.lua
;; in the repository is already changed for Guix, so no copying and no
;; editing is necessary. A name whose folder is not in the repository is
;; skipped (for example qt6ct, until you add it).
(define %linked-configs
  (filter (lambda (name)
            (file-exists? (string-append %dots "/" name)))
          '("nvim" "hypr" "waybar" "fuzzel" "alacritty" "fastfetch"
            "yazi" "helix" "qt6ct")))

;; Every file in bin/ of the repository becomes a link in ~/.local/bin
;; (nightlight, and any script that you add there later).
(define %dots-bin
  (let ((dir (string-append %dots "/bin")))
    (if (file-exists? dir)
        (map (lambda (name)
               (list (string-append ".local/bin/" name)
                     (dots-link (string-append "bin/" name))))
             (scandir dir (lambda (name)
                            (not (string-prefix? "." name)))))
        '())))

;;;
;;; Things that Guix does not have
;;;

;; oh-my-zsh and oh-my-tmux, at fixed versions. To update: change the
;; commit, run "guix home reconfigure", and copy the new hash from the error.
(define oh-my-zsh
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/ohmyzsh/ohmyzsh")
          (commit "17a2b4c3a5855524ad4772a17ada0dc474e2fdf3")))  ;2026-10-27
    (file-name "oh-my-zsh-checkout")
    (sha256
     (base32 "1pgffrmln711b9afhiqfy3ncfai5pc9lxc3081ya97545mssyllv"))))

(define oh-my-tmux
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/gpakosz/.tmux")
          ;; The same .tmux.conf that you used on Debian (2026-08-08).
          (commit "58a3dcc0d718ec0fa1c0d5a2fddd640a1ad7a5b7")))
    (file-name "oh-my-tmux-checkout")
    (sha256
     (base32 "0zky4qkndrs645xnxh6498zc8yj7y581sg72hh0h7b31a5jxng30"))))

;; Phinger cursors are not in Guix, so this file packages them.
;; Themes: phinger-cursors-dark, -light, -dark-left, -light-left.
(define phinger-cursors
  (package
    (name "phinger-cursors")
    (version "2.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/phisch/phinger-cursors"
                                  "/releases/download/v" version
                                  "/phinger-cursors-variants.tar.bz2"))
              (sha256
               (base32
                "0mkfbafxskqw02kyn81j9zvhnywglysjg41klfnrrh9q1b1wzm26"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          ;; The tarball has four theme folders and no top folder.
          ;; Unpack it here, without going into a folder.
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (invoke "tar" "xf" source))))
      #:install-plan
      #~'(("phinger-cursors-dark" "share/icons/")
          ("phinger-cursors-light" "share/icons/")
          ("phinger-cursors-dark-left" "share/icons/")
          ("phinger-cursors-light-left" "share/icons/"))))
    (home-page "https://github.com/phisch/phinger-cursors")
    (synopsis "Phinger cursor theme")
    (description
     "Phinger is a cursor theme with dark, light and left-handed variants.")
    (license license:cc-by-sa4.0)))

;; nvim-treesitter needs tree-sitter CLI 0.26.1 or later. Guix has 0.25.3,
;; so this uses the upstream release binary. The binary expects a normal
;; Linux file layout, so patchelf points it to Guix's glibc and libgcc.
(define tree-sitter-cli-bin
  (package
    (name "tree-sitter-cli-bin")
    (version "0.27.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/tree-sitter/tree-sitter"
                                  "/releases/download/v" version
                                  "/tree-sitter-linux-x64.gz"))
              (sha256
               (base32
                "0zcbr5hdjd75mn8dyaz43d1nd0sxywsy524pviyq5mm39gwl446h"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("tree-sitter" "bin/"))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (copy-file source "tree-sitter.gz")
              (invoke "gzip" "-d" "tree-sitter.gz")
              (chmod "tree-sitter" #o755)))
          (add-after 'install 'patch-elf
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin/tree-sitter")))
                (invoke "patchelf" "--set-interpreter"
                        (search-input-file inputs "/lib/ld-linux-x86-64.so.2")
                        bin)
                (invoke "patchelf" "--set-rpath"
                        (string-append
                         (dirname (search-input-file inputs "/lib/libgcc_s.so.1"))
                         ":"
                         (dirname (search-input-file inputs "/lib/libc.so.6")))
                        bin)))))))
    (native-inputs (list patchelf))
    (inputs (list glibc (list gcc "lib")))
    (supported-systems '("x86_64-linux"))
    (home-page "https://tree-sitter.github.io/")
    (synopsis "Tree-sitter command-line tool (upstream binary)")
    (description "This package provides the @command{tree-sitter} command.")
    (license license:expat)))

;; hyprpaper 0.8 draws with hyprtoolkit. Guix links hyprtoolkit to the libEGL
;; of libglvnd, but Guix's mesa is built without libglvnd, so that libEGL has
;; no driver and hyprpaper stops with
;;   CRIT from hyprtoolkit ]: [GL] eglGetProcAddress(eglCreateImageKHR) failed
;; Hyprland and hyprlock use mesa's libEGL directly, so they work.
;; This "hyprpaper" command loads mesa's EGL and GLES first, then starts the
;; real hyprpaper. Nothing is compiled. Remove it when Guix fixes hyprtoolkit.
(define hyprpaper-with-mesa
  (package
    (name "hyprpaper-with-mesa")
    (version (package-version hyprpaper))
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((bin    (string-append #$output "/bin"))
                 (script (string-append bin "/hyprpaper")))
            (mkdir-p bin)
            (call-with-output-file script
              (lambda (port)
                (format port "#!~a
export LD_PRELOAD=\"~a ~a${LD_PRELOAD:+ $LD_PRELOAD}\"
exec ~a \"$@\"~%"
                        #$(file-append bash-minimal "/bin/sh")
                        #$(file-append mesa "/lib/libEGL.so.1")
                        #$(file-append mesa "/lib/libGLESv2.so.2")
                        #$(file-append hyprpaper "/bin/hyprpaper"))))
            (chmod script #o755)))))
    (home-page (package-home-page hyprpaper))
    (synopsis "Hyprpaper, started with Mesa's EGL")
    (description
     "This package provides a @command{hyprpaper} command that loads Mesa's
EGL and GLES libraries first, then starts Hyprpaper.")
    (license (package-license hyprpaper))))


;; CaskaydiaCove Nerd Font (Cascadia Code with the Nerd Font icons). Your
;; swaync style uses "CaskaydiaCove Nerd Font Propo". Fedora had it
;; (cascadia-code-nf-fonts); Guix does not, so this file packages it.
(define font-nerd-cascadia-code
  (package
    (name "font-nerd-cascadia-code")
    (version "3.5.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/ryanoasis/nerd-fonts"
                                  "/releases/download/v" version
                                  "/CascadiaCode.tar.xz"))
              (sha256
               (base32
                "0sc3m8imzx4ii5vg0m2b9a20njg0bmqi6i9nxsinm17206a8wndf"))))
    (build-system font-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          ;; The tarball has the font files and no top folder.
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (invoke "tar" "xf" source))))))
    (home-page "https://www.nerdfonts.com/")
    (synopsis "Cascadia Code font with Nerd Font icons (CaskaydiaCove)")
    (description
     "This package provides CaskaydiaCove Nerd Font: the Cascadia Code font
with the Nerd Font icons added, in normal, Mono and Propo forms.")
    (license license:silofl1.1)))

(define swaynotificationcenter
  (specification->package "swaynotificationcenter"))

;; Your swaync/style.css starts with
;;   @import url("file:///etc/xdg/swaync/style.css");
;; That line loads the default swaync style on Fedora. Guix has no
;; /etc/xdg/swaync, so on Guix that line loads nothing, and the panel gets
;; your colors without the base style. This makes a copy of your style.css
;; that loads the default style from the swaync package instead. The file
;; in the repository does not change. After you edit it, run
;; "guix home reconfigure" again (style.css is a copy, not a link).
(define %swaync-style
  (let ((file (string-append %dots "/swaync/style.css")))
    (and (file-exists? file)
         (computed-file
          "swaync-style.css"
          #~(begin
              (use-modules (ice-9 textual-ports)
                           (srfi srfi-1))
              (let* ((default #$(file-append swaynotificationcenter
                                             "/etc/xdg/swaync/style.css"))
                     (user (call-with-input-file
                               #$(local-file (assume-valid-file-name file)
                                             "swaync-user-style.css")
                             get-string-all))
                     ;; All lines except the @import of the Fedora path.
                     (lines (remove
                             (lambda (line)
                               (and (string-prefix? "@import"
                                                    (string-trim line))
                                    (string-contains line
                                                     "swaync/style.css")))
                             (string-split user #\newline))))
                (call-with-output-file #$output
                  (lambda (port)
                    ;; A newer swaync can keep its default style inside the
                    ;; program. Then there is no file to import.
                    (if (file-exists? default)
                        (format port "@import url(\"file://~a\");~%" default)
                        (display "/* this swaync has no default style file */\n"
                                 port))
                    (display (string-join lines "\n") port)))))))))

;;;
;;; Programs
;;;

(define %my-packages
  '(;; Hyprland and its tools
    ;; hyprpaper: see hyprpaper-with-mesa above (added below, in packages)
    "hyprland" "hyprlock" "hypridle" "hyprsunset"
    "hyprpolkitagent"
    "xdg-desktop-portal" "xdg-desktop-portal-hyprland" "xdg-desktop-portal-gtk"
    "waybar" "fuzzel" "swaynotificationcenter" "libnotify"
    "grim" "slurp" "swappy" "wl-clipboard"
    "dbus" "xdg-utils" "qt6ct"
    ;; gsettings, for the dark GTK theme and cursor lines in hyprland.lua
    "glib:bin" "gsettings-desktop-schemas" "dconf"

    ;; Waybar modules and their click actions: sound, brightness, media,
    ;; network (nm-connection-editor), Bluetooth (blueman, bluetoothctl)
    "pipewire" "wireplumber" "pavucontrol"
    "brightnessctl" "playerctl"
    "network-manager-applet" "blueman" "bluez"
    ;; USB drives mount by themselves (udiskie --notify in hyprland.lua)
    "udiskie"

    ;; GNOME features on Hyprland (the swaync quick settings panel)
    "wlsunset"               ;bin/nightlight (Super+N, the Night Light button)
    "gnome-control-center"   ;the Networks, Devices and Settings buttons

    ;; Programs (the Panasonic list)
    "firefox" "bitwarden-desktop" "alacritty" "btop" "tmux" "neovim"
    "yazi" "fastfetch" "git" "curl" "wget" "fzf" "ast-grep" "lldb" "helix" "ruff"

    ;; Programs from Fedora
    "libreoffice" "hunspell-dict-en-us"   ;the dictionary: spelling check
    "mpv" "krita" "kdenlive"
    "electrum"               ;Bitcoin wallet. Restore ~/.electrum (INSTALL.md)
    "torbrowser"             ;the command is "torbrowser"
    "wine64"                 ;also runs 32-bit Windows programs
    "steam"                  ;from nonguix, runs in a container (INSTALL.md)
    "flatpak"                ;for Zen, which Guix does not have (INSTALL.md)

    ;; zsh: plugins, and the programs that your aliases use
    "zsh-autosuggestions" "zsh-syntax-highlighting"
    "eza" "bat" "gdb"
    "ncurses" "perl"   ;clear, tput (zshrc, oh-my-tmux); perl (oh-my-tmux)

    ;; Neovim (LazyVim): search, build tools for treesitter parsers
    "ripgrep" "fd" "gcc-toolchain" "make" "unzip"
    ;; Language servers from your lsp.lua. pyright, bashls and ts_ls come
    ;; from npm (see ../panasonic/INSTALL.md, F5). nixd and hls are not here.
    "clang"                  ;clangd
    "gopls" "sqls" "lua-language-server" "shfmt"
    "rust" "rust:cargo" "rust-analyzer"   ;rustaceanvim
    "node"                   ;npm, for the servers above
    ;; molten-nvim and jupytext.nvim (Python host and Jupyter)
    "python-pynvim" "python-jupyter-client@7" "python-nbformat"
    "python-ipykernel@6" "python-jupytext"
    ;; conjure + swank (your Lisp autocmd), metals (Scala)
    "sbcl" "openjdk"

    ;; Fonts and icons. Noto Sans CJK shows Japanese text.
    ;; breeze-icons: the Qt icon theme that Fedora used (breeze-dark).
    "font-nerd-jetbrains-mono" "font-google-noto" "font-google-noto-emoji"
    "font-google-noto-sans-cjk" "adwaita-icon-theme" "hicolor-icon-theme"
    "gnome-themes-extra" "breeze-icons"))

;; Like specifications->packages, but a name that Guix does not have is
;; skipped with a note, so that one wrong name does not stop the rest.
;; Read the output of "guix home reconfigure" for "skipped".
;; (specification->package stops Guix for an unknown name, so first look
;; for the name with find-best-packages-by-name.)
(define (specification->name+version spec)
  ;; "glib:bin" -> "glib" #f, "python-ipykernel@6" -> "python-ipykernel" "6"
  (let* ((colon (string-index spec #\:))
         (base  (if colon (substring spec 0 colon) spec))
         (at    (string-index base #\@)))
    (if at
        (values (substring base 0 at) (substring base (+ at 1)))
        (values base #f))))

(define (specifications->packages/skip specs)
  (filter-map
   (lambda (spec)
     (call-with-values (lambda () (specification->name+version spec))
       (lambda (name version)
         (if (null? (find-best-packages-by-name name version))
             (begin
               (format (current-error-port)
                       "home.scm: Guix has no package ~s; skipped~%" spec)
               #f)
             (call-with-values
                 (lambda () (specification->package+output spec))
               list)))))
   specs))

;; Your hyprland.lua needs Hyprland 0.55 or later. Print the version.
(let ((version (package-version (specification->package "hyprland"))))
  (format (current-error-port) "home.scm: Hyprland ~a~a~%" version
          (if (version>=? version "0.55")
              " (reads hyprland.lua)"
              " -- OLDER THAN 0.55, it does not read hyprland.lua")))

;;;
;;; Dotfiles
;;;

(define %zshrc (dots-file "zshrc" "zsh/.zshrc"))
(define %tmux-local (dots-file "tmux.conf.local" "tmux/.tmux.conf.local"))

;; Files in your home folder.
(define %home-files
  (append
   (filter
    identity
    (list
     ;; oh-my-tmux, the same as on the Panasonic.
     `(".tmux.conf" ,(file-append oh-my-tmux "/.tmux.conf"))
     (and %tmux-local `(".tmux.conf.local" ,%tmux-local))
     ;; options.lua uses ~/.virtualenvs/neovim/bin/python3 as the Python
     ;; host. Point it to the Python that has pynvim and jupyter_client.
     `(".virtualenvs/neovim/bin/python3" ,(file-append python "/bin/python3"))))
   ;; ~/.local/bin/nightlight and the other scripts in bin/.
   %dots-bin))

;; Files in ~/.config.
(define %config-files
  (append
   (map (lambda (name) (list name (dots-link name)))
        %linked-configs)
   (filter
    identity
    (list
     (and (file-exists? (string-append %dots "/swaync/config.json"))
          `("swaync/config.json" ,(dots-link "swaync/config.json")))
     (and %swaync-style
          `("swaync/style.css" ,%swaync-style))))))

(home-environment
 (packages (cons* phinger-cursors
                  tree-sitter-cli-bin
                  python
                  hyprpaper-with-mesa
                  font-nerd-cascadia-code
                  (specifications->packages/skip %my-packages)))
 (services
  (list
   (simple-service
    'session-variables home-environment-variables-service-type
    '(;; Where Hyprland and other programs look for cursor themes. Guix's
      ;; default list does not include the Guix Home profile.
      ("XCURSOR_PATH"
       . "$HOME/.local/share/icons:$HOME/.icons:$HOME/.guix-home/profile/share/icons:/run/current-system/profile/share/icons")
      ;; Flatpak programs (Zen) in the fuzzel menu.
      ("XDG_DATA_DIRS"
       . "$XDG_DATA_DIRS:$HOME/.local/share/flatpak/exports/share")))
   ;; Session D-Bus. PipeWire, the portals and notifications need it.
   (service home-dbus-service-type)
   ;; PipeWire + WirePlumber, with PulseAudio support (Waybar sound module).
   (service home-pipewire-service-type)
   ;; zsh: oh-my-zsh from Guix, then your .zshrc from the repository.
   ;; (Hyprland is started by tuigreet, see config.scm.)
   (service home-zsh-service-type
            (home-zsh-configuration
             (zshrc
              (filter identity
                      (list (mixed-text-file "oh-my-zsh-path"
                                             "export ZSH=" oh-my-zsh "\n")
                            %zshrc)))))
   (simple-service 'dotfiles home-files-service-type %home-files)
   (simple-service 'config-files home-xdg-configuration-files-service-type
                   %config-files))))
