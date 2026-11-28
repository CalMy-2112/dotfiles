# ~/.profile (symlink to zsh/.profile in the dots repo): the environment for
# the whole login. ~/.xinitrc reads it (startx and LightDM), and ~/.zprofile
# reads it for zsh logins (tty, ssh, tmux panes). Keep it POSIX sh.
# Interactive things (aliases, oh-my-zsh, opam's zsh hook) stay in ~/.zshrc.

export EDITOR="nvim"
export CARGO_MOMMYS_MOODS="ominous/thirsty/yikes"
export GTK_THEME=Adwaita:dark
export SAL_USE_VCLPLUGIN=gtk3
export GOPATH="$HOME/go"

# Add a folder to the front of PATH only once (tmux panes and startx from a
# login shell read this file again).
_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
# Reverse order: the last one ends up first.
_path_prepend "$HOME/.local/share/coursier/bin"
_path_prepend "$GOPATH/bin"
_path_prepend "$HOME/.cargo/bin"
_path_prepend "$HOME/.local/bin"
unset -f _path_prepend
export PATH

[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env" # ghcup-env
