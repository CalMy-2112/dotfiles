# ~/.zprofile (symlink to zsh/.zprofile in the dots repo): zsh login shells
# (tty, ssh, tmux panes) read the shared environment in ~/.profile.
[[ -r "$HOME/.profile" ]] && emulate sh -c '. "$HOME/.profile"'
