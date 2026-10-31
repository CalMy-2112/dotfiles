# Guix configs

One folder for each laptop. `channels.scm` is shared.

    guix/
      channels.scm     Guix + nonguix + tailscale (both laptops)
      panasonic/       Panasonic CF-SZ5 (user osho)
        config.scm       the system
        home.scm         programs and dotfiles
        circscroll.c     circular scrolling for the round touchpad
        INSTALL.md       install steps
      gram/            LG gram 16 2-in-1 16T90R (user calmy)
        config.scm       the system
        home.scm         programs and dotfiles
        installer.scm    Guix installer with Wi-Fi (build it on the Panasonic)
        INSTALL.md       install steps

The dotfiles that both laptops use (hypr/, waybar/, nvim/, swaync/, bin/,
...) are at the top of the repository. Each home.scm finds them two folders
above itself (`%dots`).

The Panasonic uses its own copy of home.scm in ~/.config/home.scm (some
lines are different there). To keep the real one in the repository, copy it
to guix/panasonic/home.scm and check that its %dots line is:

    (define %dots (dirname (dirname (current-source-directory))))

Commands:

    # Panasonic
    sudo guix system reconfigure ~/dots/guix/panasonic/config.scm
    guix home reconfigure ~/dots/guix/panasonic/home.scm

    # gram
    sudo guix system reconfigure ~/dots/guix/gram/config.scm
    guix home reconfigure ~/dots/guix/gram/home.scm
