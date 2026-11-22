# cccru.zsh-theme: neon green on black, from cccru.ca's style.css.
# Sourced from .zshrc after oh-my-zsh (needs its git_prompt_info).
# Needs a truecolor terminal (alacritty sets COLORTERM=truecolor).
#
#   ~/dots [main *] ❯
#   (user@host only shows over SSH; the arrow turns red after a failed command)

typeset -g _c_neon='#11ff7a' _c_dim='#0bbf5b' _c_dark='#2d732d' \
           _c_ink='#e9efe9' _c_muted='#b7c9b7' _c_mint='#6fd495' \
           _c_pale='#9bd8ae' _c_violet='#c3a6ff' _c_red='#ff6b6b' \
           _c_comment='#4f6b55'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{$_c_dark}[%F{$_c_pale}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{$_c_dark}]%f "
ZSH_THEME_GIT_PROMPT_DIRTY=" %F{$_c_violet}*"
ZSH_THEME_GIT_PROMPT_CLEAN=""

_cccru_host() {
  [[ -n "$SSH_CONNECTION" ]] && print -n "%F{$_c_neon}%n%F{$_c_dark}@%F{$_c_mint}%m "
}

setopt prompt_subst
PROMPT='$(_cccru_host)%F{$_c_muted}%~%f $(git_prompt_info)%(?.%F{$_c_neon}.%F{$_c_red})❯%f '
RPROMPT='%(?..%F{$_c_red}%?%f)'

# zsh-autosuggestions (sourced later in .zshrc; it keeps a value set here)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#4a5a4a"

# zsh-syntax-highlighting (sourced later; it only fills in unset styles)
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]="fg=$_c_neon"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=$_c_neon"
ZSH_HIGHLIGHT_STYLES[alias]="fg=$_c_neon"
ZSH_HIGHLIGHT_STYLES[function]="fg=$_c_neon"
ZSH_HIGHLIGHT_STYLES[precommand]="fg=$_c_neon,underline"
ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=$_c_dim"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=$_c_red"
ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=$_c_dark"
ZSH_HIGHLIGHT_STYLES[path]="fg=$_c_ink,underline"
ZSH_HIGHLIGHT_STYLES[globbing]="fg=$_c_violet"
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=$_c_pale"
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=$_c_pale"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=$_c_mint"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=$_c_mint"
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=$_c_mint"
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]="fg=$_c_violet"
ZSH_HIGHLIGHT_STYLES[redirection]="fg=$_c_dim"
ZSH_HIGHLIGHT_STYLES[comment]="fg=$_c_comment,italic"
ZSH_HIGHLIGHT_STYLES[default]="fg=$_c_ink"
