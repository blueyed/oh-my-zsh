# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html
# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Zle-Builtins
# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Standard-Widgets

# Make sure that the terminal is in application mode when zle is active, since
# only then values from $terminfo are valid
# NOTE: this calls any previously defined zle widgets (chained).
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
  eval "zle-line-init()   { echoti smkx; $functions[${widgets[zle-line-init]#*:}] }"
  eval "zle-line-finish() { echoti rmkx; $functions[${widgets[zle-line-finish]#*:}] }"
  zle -N zle-line-init
  zle -N zle-line-finish
fi

bindkey -v                                            # Use vim key bindings

bindkey '\ew' kill-region                             # [Esc-w] - Kill from the cursor to the mark
bindkey '^r' history-incremental-search-backward      # [Ctrl-r] - Search backward incrementally for a specified string. The string may begin with ^ to anchor the search to the beginning of the line.
if [[ "${terminfo[kpp]}" != "" ]]; then
  bindkey "${terminfo[kpp]}" up-line-or-history       # [PageUp] - Up a line of history
fi
if [[ "${terminfo[knp]}" != "" ]]; then
  bindkey "${terminfo[knp]}" down-line-or-history     # [PageDown] - Down a line of history
fi

if [[ "${terminfo[kcuu1]}" != "" ]]; then
  bindkey "${terminfo[kcuu1]}" up-line-or-search      # start typing + [Up-Arrow] - fuzzy find history forward
fi
if [[ "${terminfo[kcud1]}" != "" ]]; then
  bindkey "${terminfo[kcud1]}" down-line-or-search    # start typing + [Down-Arrow] - fuzzy find history backward
fi

if [[ "${terminfo[khome]}" != "" ]]; then
  bindkey "${terminfo[khome]}" beginning-of-line      # [Home] - Go to beginning of line
  bindkey -M vicmd "${terminfo[khome]}" vi-beginning-of-line
fi
if [[ "${terminfo[kend]}" != "" ]]; then
  bindkey "${terminfo[kend]}"  end-of-line            # [End] - Go to end of line
  bindkey -M vicmd "${terminfo[kend]}" end-of-line
fi

bindkey ' ' magic-space                               # [Space] - do history expansion

bindkey '^[[1;5C' forward-word                        # [Ctrl-RightArrow] - move forward one word
bindkey '^[[1;5D' backward-word                       # [Ctrl-LeftArrow] - move backward one word

if [[ "${terminfo[kcbt]}" != "" ]]; then
  bindkey "${terminfo[kcbt]}" reverse-menu-complete   # [Shift-Tab] - move through the completion menu backwards
fi

bindkey '^?' backward-delete-char                     # [Backspace] - delete backward
if [[ "${terminfo[kdch1]}" != "" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char            # [Delete] - delete forward
  bindkey -M vicmd "${terminfo[kdch1]}" vi-delete-char
else
  bindkey "^[[3~" delete-char
  bindkey "^[3;5~" delete-char
  bindkey "\e[3~" delete-char
fi

# up / down search in history for the current line's prefix
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
# Shift-up / Shift-down: consider first word only
bindkey '^[[1;2A' up-line-or-search
bindkey '^[[1;2B' down-line-or-search

# Remap default C-p / C-p from up-line-or-history.
bindkey '^P' up-line-or-beginning-search
bindkey '^N' down-line-or-beginning-search

bindkey "^[[H" beginning-of-line
bindkey "^[[1~" beginning-of-line
bindkey "^[OH" beginning-of-line
bindkey "^[[F"  end-of-line
bindkey "^[[4~" end-of-line
bindkey "^[OF" end-of-line
bindkey '\e[2~' overwrite-mode # insert key
bindkey '\e[3~' delete-char    # delete key


# consider emacs keybindings:

#bindkey -e  ## emacs key bindings
#
#bindkey '^[[A' up-line-or-search
#bindkey '^[[B' down-line-or-search
#bindkey '^[^[[C' emacs-forward-word
#bindkey '^[^[[D' emacs-backward-word
#
#bindkey -s '^X^Z' '%-^M'
#bindkey '^[e' expand-cmd-path
#bindkey '^[^I' reverse-menu-complete]
#bindkey '^X^N' accept-and-infer-next-history
#bindkey '^W' kill-region
#bindkey '^I' complete-word
## Fix weird sequence that rxvt produces
#bindkey -s '^[[Z' '\t'
#


# from old bindkey.zsh:

# Use VIM keymap
# bindkey -v

# Re-add Ctrl-R
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M vicmd '^r' history-incremental-search-backward

# push-line, which handles PS2 and starts vi insert mode.
my-push-line-and-insert() {
  zle push-line-or-edit
  zle vi-insert
}
zle -N my-push-line-and-insert
bindkey -M vicmd 'q' my-push-line-and-insert
bindkey -M viins '\eq' my-push-line-and-insert

bindkey -M vicmd 'u' undo # stacked undo!
# Map run-help also in vicmd mode.
bindkey -M vicmd "\eh" run-help
bindkey -M viins 'jk' vi-cmd-mode
# bindkey -M viins 'kj' vi-cmd-mode
bindkey -M viins ' ' magic-space
bindkey -M viins '\C-i' complete-word

# insert key
bindkey '\e[2~' overwrite-mode
# delete key
bindkey '\e[3~' delete-char

# Special keys handling, at least required for delete-char with "bindkey -v".
# Via http://wiki.archlinux.org/index.php/Zsh#Key_Bindings
bindkey "\e[1~" beginning-of-line
bindkey "\e[4~" end-of-line
bindkey "\e[5~" beginning-of-history
bindkey "\e[6~" end-of-history
bindkey "\e[3~" delete-char
bindkey "\e[2~" quoted-insert
bindkey "\e[5C" forward-word
bindkey "\eOc" emacs-forward-word
bindkey "\e[5D" backward-word
bindkey "\eOd" emacs-backward-word
bindkey "\e\e[C" forward-word
bindkey "\e\e[D" backward-word
# for rxvt
bindkey "\e[8~" end-of-line
bindkey "\e[7~" beginning-of-line
# for non RH/Debian xterm, can't hurt for RH/Debian xterm (used by gnome-terminal)
bindkey "\eOH" beginning-of-line
bindkey "\eOF" end-of-line
# for freebsd console
bindkey "\e[H" beginning-of-line
bindkey "\e[F" end-of-line


# some more, via http://github.com/blueyed/dotfiles/blob/6750c9c9bc82f9ce9d727e026817ed48edb40ef1/zsh/config
bindkey '^[^[[D' backward-word
bindkey '^[^[[C' forward-word
bindkey '^[[5D' beginning-of-line
bindkey '^[[5C' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[^N' newtab

# Overwrite vi-backward-kill-word, which stops at where insert mode was last entered.
bindkey '^w' backward-kill-word

# Useful bindings from emacs set.
bindkey "^X*"  expand-word
bindkey "^X^U" undo
bindkey "^Xu"  undo

autoload -U smart-insert-last-word
zle -N insert-last-assignment smart-insert-last-word
zstyle :insert-last-assignment match '[[:alpha:]][][[:alnum:]]#=*'
bindkey '\e=' insert-last-assignment

zle -N insert-last-word smart-insert-last-word
bindkey -M viins "^[." insert-last-word
