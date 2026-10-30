# .zshrc -- from Debian, changed for Guix.
# Guix Home puts this file at ~/.config/zsh/.zshrc (see guix/home.scm).
#
# Changes from the Debian file:
#  - ZSH: Guix sets it to its copy of oh-my-zsh (home.scm). On another
#    system, ~/.oh-my-zsh is used as before.
#  - The Guix copy is read-only: the cache goes to ~/.cache/oh-my-zsh, and
#    auto-update is off. "guix pull" + "guix home reconfigure" updates it.
#  - Plugin paths: the Guix profile first, then /usr/share (Debian).
#  - PATH uses $HOME (it had /home/calmy). The coursier PATH line was inside
#    the ghcup comment, so it did nothing. It is now its own line.

# Detect Emacs' M-x term. INSIDE_EMACS survives tmux launching (unlike
# $TERM, which tmux overwrites), so check that instead.
if [[ "$INSIDE_EMACS" == *"term:"* ]]; then
  IN_EMACS_TERM=1
fi

# Oh My Zsh
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"
zstyle ':omz:update' mode disabled

ZSH_THEME="simple"
plugins=(git sudo z extract colored-man-pages command-not-found history-substring-search)

if [[ -z "$IN_EMACS_TERM" ]]; then
  source $ZSH/oh-my-zsh.sh
fi

# aliases
alias ll='eza -lha'
alias :q='exit'
alias python='python3'
alias cls='clear'
alias cat='bat'
alias vi='hx'
alias vim='hx'
alias nvim='hx'
alias gdb='gdb -q'

clear
fastfetch

export EDITOR="nvim"
export CARGO_MOMMYS_MOODS="ominous/thirsty/yikes"
export GTK_THEME=Adwaita:dark
export SAL_USE_VCLPLUGIN=gtk3
export GOPATH=$HOME/go
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$GOPATH/bin:$HOME/.local/share/coursier/bin:$PATH"
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env" # ghcup-env

# zsh-autosuggestions and zsh-syntax-highlighting (syntax highlighting last).
for _plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  for _dir in "$HOME/.guix-home/profile/share/zsh/plugins/$_plugin" "/usr/share/$_plugin"; do
    if [[ -r "$_dir/$_plugin.zsh" ]]; then
      source "$_dir/$_plugin.zsh"
      break
    fi
  done
done
unset _plugin _dir
