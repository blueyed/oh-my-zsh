# ls colors
autoload colors; colors;
export LSCOLORS="Gxfxcxdxbxegedabagacad"
export LS_COLORS

# Enable ls colors
if [ "$DISABLE_LS_COLORS" != "true" ]; then
  # Find the option for using colors in ls, depending on the version: Linux or BSD

  # NOTE: Do not overwrite own aliases
  # ls --color -d . &>/dev/null 2>&1 && alias ls='ls --color=tty' || alias ls='ls -G'

  # setup LS_COLORS
  # (dircolors on GNU/Linux, gdircolors with coreutils on MacOS)
  for i in dircolors gdircolors; do
    if [ $commands[$i] ]; then
      dircolors=$i ; break
    fi
  done
  if [ -n "$dircolors" ]; then
    # : ${DIRCOLORS_FILE:=~/.dotfiles/lib/dircolors-solarized/dircolors.256dark}
    : ${DIRCOLORS_FILE:=~/.dotfiles/lib/LS_COLORS/LS_COLORS}
    if [ -f $DIRCOLORS_FILE ] ; then
      # Redirect errors: e.g. 'unrecognized keyword RESET' on CentOS 5.4
      eval $($dircolors -b $DIRCOLORS_FILE 2>/dev/null)
    else
      eval $($dircolors -b)
    fi
  fi
fi

#setopt no_beep
setopt auto_cd
setopt multios
# setopt cdablevars

if [[ x$WINDOW != x ]]
then
    SCREEN_NO="%B$WINDOW%b "
else
    SCREEN_NO=""
fi

# Apply theming defaults
PS1="%n@%m:%~%# "

# git theming default: Variables for theming the git info prompt
ZSH_THEME_GIT_PROMPT_PREFIX="git:("         # Prefix at the very beginning of the prompt, before the branch name
ZSH_THEME_GIT_PROMPT_SUFFIX=")"             # At the very end of the prompt
ZSH_THEME_GIT_PROMPT_DIRTY="*"              # Text to display if the branch is dirty
ZSH_THEME_GIT_PROMPT_CLEAN=""               # Text to display if the branch is clean

# Setup the prompt with pretty colors
setopt prompt_subst

