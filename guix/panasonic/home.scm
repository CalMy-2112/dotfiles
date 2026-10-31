;; home.scm -- programs, dotfiles and user services for osho (Guix Home)
;;
;;   guix home reconfigure ~/dots/guix/panasonic/home.scm
;;
;; This file is in the guix/ folder of your dotfiles repository (~/dots).
;; It uses these files from the repository, if they are there:
;;   zsh/.zshrc               -> ~/.config/zsh/.zshrc
;;   tmux/.tmux.conf.local    -> ~/.tmux.conf.local
;;   wallpapers/bay.jpg       -> ~/Pictures/wallpapers/photography/kainoa-kanter/bay.jpg
;;   nvim/                    -> ~/.config/nvim (a link, so it stays editable)
;; Other configs (hypr, waybar, ...) stay copies in ~/.config. To link them
;; too, add their names to %linked-configs below.
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
             (guix build-system trivial)
             (guix download)
             (guix gexp)
             (guix git-download)
             ((guix licenses) #:prefix license:)
             (guix packages)
             (guix utils))

;;;
;;; The dotfiles repository
;;;

;; Two folders above this file (guix/panasonic/), for example /home/osho/dots.
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

;; A link to a folder in the repository. The files are not copied to the
;; store, so you can edit them (and lazy.nvim can write lazy-lock.json).
(define (dots-link relative)
  (computed-file (string-append (basename relative) "-link")
                 #~(symlink #$(string-append %dots "/" relative) #$output)))

;; Configs in ~/.config that are links to the repository.
;; Before you add "hypr", "waybar", ..., put your changed copies from
;; ~/.config into the repository. Guix moves the old ~/.config copies to a
;; backup folder in your home.
(define %linked-configs '("nvim"))

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
    ;; gsettings, for the dark GTK theme line in your Hyprland config
    "glib:bin" "gsettings-desktop-schemas" "dconf"

    ;; Waybar modules and their click actions: sound, brightness, media,
    ;; network (nm-connection-editor), Bluetooth (blueman, bluetoothctl)
    "pipewire" "wireplumber" "pavucontrol"
    "brightnessctl" "playerctl"
    "network-manager-applet" "blueman" "bluez"
    ;; USB drives mount by themselves (udiskie --notify in hyprland.lua)
    "udiskie"

    ;; Programs
    "firefox" "bitwarden-desktop" "alacritty" "btop" "tmux" "neovim"
    "yazi" "fastfetch" "git" "curl" "wget" "fzf" "ast-grep" "lldb" "helix" "ruff"

    ;; zsh: plugins, and the programs that your aliases use
    "zsh-autosuggestions" "zsh-syntax-highlighting"
    "eza" "bat" "gdb"
    "ncurses" "perl"   ;clear, tput (zshrc, oh-my-tmux); perl (oh-my-tmux)

    ;; Neovim (LazyVim): search, build tools for treesitter parsers
    "ripgrep" "fd" "gcc-toolchain" "make" "unzip"
    ;; Language servers from your lsp.lua. pyright, bashls and ts_ls come
    ;; from npm (see INSTALL.md). nixd and hls are not here.
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
    "font-nerd-jetbrains-mono" "font-google-noto" "font-google-noto-emoji"
    "font-google-noto-sans-cjk" "adwaita-icon-theme" "hicolor-icon-theme" "gnome-themes-extra"))

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
(define %wallpaper (dots-file "bay.jpg" "wallpapers/bay.jpg"))

(define %home-files
  (filter
   identity
   (list
    ;; oh-my-tmux, like the link that you made on Debian.
    `(".tmux.conf" ,(file-append oh-my-tmux "/.tmux.conf"))
    (and %tmux-local `(".tmux.conf.local" ,%tmux-local))
    ;; The path that hyprpaper.conf uses.
    (and %wallpaper
         `("Pictures/wallpapers/photography/kainoa-kanter/bay.jpg" ,%wallpaper))
    ;; options.lua uses ~/.virtualenvs/neovim/bin/python3 as the Python
    ;; host. Point it to the Python that has pynvim and jupyter_client.
    `(".virtualenvs/neovim/bin/python3" ,(file-append python "/bin/python3")))))

(home-environment
 (packages (cons* phinger-cursors
                  tree-sitter-cli-bin
                  python
                  hyprpaper-with-mesa
                  (specifications->packages %my-packages)))
 (services
  (list
   ;; Where Hyprland and other programs look for cursor themes. Guix's
   ;; default list does not include the Guix Home profile.
   (simple-service 'cursor-path home-environment-variables-service-type
                   '(("XCURSOR_PATH"
                      . "$HOME/.local/share/icons:$HOME/.icons:$HOME/.guix-home/profile/share/icons:/run/current-system/profile/share/icons")))
   ;; Session D-Bus. PipeWire, the portals and notifications need it.
   (service home-dbus-service-type)
   ;; PipeWire + WirePlumber, with PulseAudio support (Waybar sound module).
   (service home-pipewire-service-type)
   ;; zsh: oh-my-zsh from Guix, then your .zshrc from the repository.
   ;; (Hyprland is started by tuigreet now, see config.scm.)
   (service home-zsh-service-type
            (home-zsh-configuration
             (zshrc
              (filter identity
                      (list (mixed-text-file "oh-my-zsh-path"
                                             "export ZSH=" oh-my-zsh "\n")
                            %zshrc)))))
   (simple-service 'dotfiles home-files-service-type %home-files)
   (simple-service 'linked-configs home-xdg-configuration-files-service-type
                   (map (lambda (name) (list name (dots-link name)))
                        %linked-configs)))))
