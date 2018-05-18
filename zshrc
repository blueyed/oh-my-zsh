# TODO: trap on Ctrl-D / exit if there are stashed changes in a directory (similar to background processes)
#       (similar to CHECK_JOBS)
# TODO: alias/function to trash a file (mv it to ~/.local/share/Trash/…)
#
# NOTE: $path adjustment is done in .zshenv

# Setup/manage MY_X_THEME_VARIANT.
# Do this as early as possible, because it needs to change tmux window options.
BASE16_SHELL_DIR=~/.dotfiles/lib/base16/base16-shell
base16_theme() {
  local theme
  if [[ -n "$1" ]]; then
    theme=$1
    # echo "Loading base16 theme: $BASE16_THEME..." >&2
  elif [[ -z $theme ]]; then
    theme="solarized.${MY_X_THEME_VARIANT:-dark}"
  fi
  local theme_file=$BASE16_SHELL_DIR/base16-$theme.sh
  if ! [[ -s $theme_file ]]; then
    echo "$theme_file does not exist." >&2
    return 1
  fi
  local tmux
  if [[ -n "$TMUX" ]]; then
    if [[ "$TTY" != "$(tmux display -p '#{pane_tty}')" ]]; then
      tmux=
    else
      tmux="$TMUX"
    fi
  fi
  TMUX="$tmux" source $theme_file
  export BASE16_THEME=$theme
}
theme-variant() {
    if (( ${@[(I)-q]} )); then
        # Call the script for '-q'.
        ~/.dotfiles/usr/bin/sh-setup-x-theme "$@"
    else
        eval "$(~/.dotfiles/usr/bin/sh-setup-x-theme "$@")"
        # local cmds="$(~/.dotfiles/usr/bin/sh-setup-x-theme "$@")"
        # # echo "$cmds"
        # eval "$cmds"
    fi
}
# Setup/init X theme variant (shell only).
eval "$(~/.dotfiles/usr/bin/sh-setup-x-theme -s)"

# Path to your oh-my-zsh configuration.
export ZSH=$HOME/.dotfiles/oh-my-zsh

# Profiling / Tracing. {{{
# Start debug tracing (NOTE: does not work from a function).
# if true; then
#   PS4='+$(date "+%s:%N") %N:%i> '
#   zsh_xtrace_file=/tmp/zsh-xtrace.$$.log
#   echo "Tracing into $zsh_xtrace_file"
#   exec 3>&2 2>$zsh_xtrace_file
#   setopt xtrace prompt_subst
# fi
# # Stop debug tracing.
# zsh_stop_debug_xtrace() {
#   unsetopt xtrace
#   exec 2>&3 3>&-
# }

# Start profiling; call zprof to output results.
# zmodload zsh/zprof
# }}}

# Set to the name theme to load.
# Look in ~/.oh-my-zsh/themes/
export ZSH_THEME="blueyed"

# Set to this to use case-sensitive completion
# export CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
export DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# export DISABLE_LS_COLORS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Example format: plugins=(rails git textmate ruby ighthouse)
plugins=(git dirstack)
if (( $+commands[apt-get] )); then
  plugins+=(apt)
fi

fpath=(~/.dotfiles/lib/zsh-completions/src $fpath)

# Define FZF_DEFAULT_OPTS before the theme gets loaded.
# Should not be overwritten in case it exists (tmux).
if (( $+commands[fzf] )) && ! (( $+FZF_DEFAULT_OPTS )); then
  export FZF_DEFAULT_OPTS=--extended
fi

# Autoload all functions.  Needs to come before theme for is_ssh/is_remote.
autoload $ZSH/functions/[^_]*(:t)

source $ZSH/oh-my-zsh.sh

compdef "compadd $BASE16_SHELL_DIR/*.sh(:t:r:s/base16-/)" base16_theme
compdef -e '_arguments "1: :(auto light dark)" "2: :(save)"' theme-variant

# fzf. {{{
if (( $+commands[fzf] )); then
  source ~/.config/fzf.zsh
else
  if [[ -x ~/.dotfiles/lib/fzf/bin/fzf ]]; then
    path+=(~/.dotfiles/lib/fzf/bin)
    source ~/.config/fzf.zsh
  else
    echo "fzf does not exist.  To install it: '~/.dotfiles/lib/fzf/install --bin'." >&2
  fi
fi # }}}

# Customize to your needs...

REPORTTIME=10 # print elapsed time when more than 10 seconds

setopt MAIL_WARNING
setopt HIST_IGNORE_SPACE # Ignore commands with leading space

setopt NUMERIC_GLOB_SORT
setopt EXTENDED_GLOB

# hows about arrays be awesome?  (that is, frew${cool}frew has frew surrounding all the variables, not just first and last
setopt RC_EXPAND_PARAM

setopt PUSHD_SILENT # make popd quiet

setopt CORRECT # do not use CORRECT_ALL

export RI="--format ansi"


# directory based VCS before repo based ones (e.g. CVS in $HOME, the latter using Git)
# zstyle ':vcs_info:*' enable cvs svn bzr hg git
zstyle ':vcs_info:*' enable git hg
# zstyle ':vcs_info:bzr:*' use-simple true
zstyle ':vcs_info:(hg|svn):*' use-simple false
zstyle ':vcs_info:(bzr|hg|svn):*' use-simple true
zstyle ':vcs_info:*:prompt:*' hgrevformat '%r'

# check-for-changes can be really slow.
# Enable it depending on the current dir's filesystem type.
autoload -U add-zsh-hook

# Set ZSH_IS_SLOW_DIR.
_is_slow_file_system() {
  df_T=$(command df -T . 2>/dev/null) || true
  if [[ $df_T == '' ]]; then
    # 'df -T' might not be available (busybox, diskstation).
    # 'stat -f' does not detect cifs (type UNKNOWN).
    # fs_type=$(stat -f . | grep -o 'Type:.*' | cut -f2 -d\ )
    mount_point="$(command df . | awk 'END {print $NF}')"
    fs_type=$(mount | awk '$3 == "'$mount_point'" { print $5 }')
  else
    # Get 2nd word from 2nd line.
    fs_type=${${(z)${(f)df_T}[2]}[2]}
  fi

  case $fs_type in
    (sshfs|nfs|cifs|fuse.bup-fuse) return 0 ;;
    (*) return 1;;
  esac
}
_zshrc_chpwd_detect_slow_dir() {
  if [[ $PWD == /run/user/*/gvfs/* ]] || [[ $PWD == ~/.gvfs/mtp/* ]] \
    || _is_slow_file_system; then
    if [[ $ZSH_IS_SLOW_DIR != 1 ]]; then
      echo "NOTE: on slow fs" >&2
    fi
    ZSH_IS_SLOW_DIR=1
  else
    ZSH_IS_SLOW_DIR=0
  fi
  export ZSH_IS_SLOW_DIR
}
add-zsh-hook chpwd _zshrc_chpwd_detect_slow_dir 2>/dev/null || {
  echo '_zshrc_chpwd_detect_slow_dir: failed loading add-zsh-hook.' >&2
}
# Init:
_zshrc_chpwd_detect_slow_dir


add-zsh-hook chpwd _zshrc_vcs_check_for_changes_hook # {{{
_zshrc_vcs_check_for_changes_hook() {
  local -h check_for_changes
  if [[ -n $ZSH_CHECK_FOR_CHANGES ]]; then
    # override per env:
    check_for_changes=$ZSH_CHECK_FOR_CHANGES
  elif (( $ZSH_IS_SLOW_DIR )); then
    zstyle -t ':vcs_info:*:prompt:*' 'check-for-changes'
    if [[ $? == 0 ]]; then
      echo "on slow fs: check_for_changes => false"
      zstyle ':vcs_info:*:prompt:*' check-for-changes false
    fi
  else
    zstyle -t ':vcs_info:*:prompt:*' 'check-for-changes'
    local rv=$?
    if [[ $rv != 0 ]]; then
      if [[ $rv == 1 ]]; then
        # was false (and not unset):
        echo "on fast fs: check_for_changes => true"
      fi
      zstyle ':vcs_info:*:prompt:*' check-for-changes true
    fi
  fi
}
# init
_zshrc_vcs_check_for_changes_hook  # }}}

# Incremental search
bindkey -M vicmd "/" history-incremental-search-backward
bindkey -M vicmd "?" history-incremental-search-forward

# Remap C-R/C-S to use patterns
if (( ${+widgets[history-incremental-pattern-search-backward]} )); then
  # since 4.3.7, not in Debian Lenny
  bindkey "^R" history-incremental-pattern-search-backward
  bindkey "^S" history-incremental-pattern-search-forward
fi

# Search based on what you typed in already
bindkey -M vicmd "//" history-beginning-search-backward
bindkey -M vicmd "??" history-beginning-search-forward

# <Esc>-h runs help on current BUFFER
bindkey "\eh" run-help

# TODO: http://zshwiki.org/home/zle/bindkeys%22%22
bindkey -M vicmd "\eOH" beginning-of-line
bindkey -M vicmd "\eOF" end-of-line
# bindkey "\e[1;3D" backward-word
# bindkey "\e[1;3C" forward-word

# Replace current buffer with executed result (vicmd mode)
bindkey -M vicmd '!' edit-command-output
edit-command-output() {
  BUFFER=$(eval $BUFFER)
  CURSOR=0
}
zle -N edit-command-output

# Make files executable via associated apps
# XXX: slow?!
# NOTE: opens .py files in less, although they are executable!
# autoload -U zsh-mime-setup
# zsh-mime-setup
# Do not break invoke-rc.d completion
unalias -s d 2>/dev/null

watch=(notme)

# Load bash completion system
# via http://zshwiki.org/home/convert/bash
autoload -U bashcompinit
bash_source() {
  alias shopt=':'
  alias _expand=_bash_expand
  alias _complete=_bash_comp
  emulate -L sh
  setopt kshglob noshglob braceexpand

  source "$@"
}
# Load completion from bash, which isn't available in zsh yet.
bash_completions=()
if [ -n "$commands[vzctl]" ] ; then
  bash_completions+=(/etc/bash_completion.d/vzctl.sh)
fi
if (( $#bash_completions )); then
  if ! which complete &>/dev/null; then
    autoload -Uz bashcompinit
    if which bashcompinit &>/dev/null; then
      bashcompinit
    fi
  fi
  bash_source /etc/bash_completion.d/vzctl.sh
fi


# run-help for builtins
unalias run-help &>/dev/null
autoload run-help

autoload -U edit-command-line
zle -N edit-command-line
bindkey '\ee' edit-command-line

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval $(lesspipe)

# Options for less: move jump target to line 5 and handle ANSI color
# sequences (default, but required with $LESS set?!), for "git diff".
# Also: (smart-)ignore case and do not fold long lines.
# -X: do not use alternate screen (smcup/rmcup).
export LESS="-j5 -R -i -S -X"
# Alias for `less`, without `-X`.
alias lessx='LESS="-j5 -R -i -S" less'
compdef lessx=less

# just type '...' to get '../..'
# Originally by grml, improved by Mikachu
if zmodload zsh/regex 2>/dev/null; then # might not be available (e.g. on DS212+)
  autoload -Uz rationalise-dot  # in ~/.dotfiles/oh-my-zsh/functions/rationalise-dot
  zle -N rationalise-dot
  bindkey . rationalise-dot
  # without this, typing a . aborts incremental history search
  # "isearch" does not exist in zsh 4.3.6 (Debian Lenny)
  bindkey -M isearch . self-insert 2>/dev/null
fi

# . => "cd ." (reloads vcs_info); otherwise source.
.() { [ $# = 0 ] && cd . || builtin . "$@"; }

# Completion for custom docker scripts.
compdef _docker docker-shell=_docker_containers

# Assume 256 colors with xterm/screen when $DISPLAY or $COLORTERM is given.
if [[ -n $DISPLAY ]] || [[ -n $COLORTERM ]] || is_remote; then
  if [[ $TERM == "xterm" ]]; then
    export TERM=xterm-256color
  elif [[ $TERM == "screen" ]]; then
    export TERM=screen-256color
  fi
fi

# Fix up TERM if there's no info for the currently set one (might cause programs to fail)
if ! tput longname &> /dev/null; then
  echo "tput longname failed (TERM=$TERM)!"
  if [[ ! -e ~/.terminfo && -d ~/.dotfiles/terminfo ]]; then
    echo "Linking terminfo, you should probably restart the shell."
    ln -s .dotfiles/terminfo ~/.terminfo
  else
    echo "Setting fallback TERM:"
    set -x
    if   [[ $TERM == screen-256color-it ]]; then TERM=screen-256color
    elif [[ $TERM == screen*bce ]]; then TERM=screen-bce
    elif [[ $TERM == screen* ]]; then TERM=screen
    else TERM=xterm fi
    export TERM
    set +x
  fi
fi

setopt GLOB_COMPLETE # helps with "setopt *alias<tab>" at least

# (Neo)vim setup {{{
# Setup EDITOR env var (should be a command) and "vi" alias.
() {
  local cmd
  for cmd in nvim vim vi; do
    if [[ -n $commands[(I)$cmd] ]]; then
      export EDITOR=$cmd
      alias vi=$cmd
      if [[ $cmd == nvim ]]; then
        alias view='nvim -R'
        alias vimdiff='nvim -d'
      fi
      break
    fi
  done
}

# Edit a tag within a given base dir, e.g. `vit ~df vit`, where `vit ~df` is
# aliased to `vdf` - so you can use `vdf vit` to edit this functon.
# cd'ing in a subshell with DIRSTACKFILE unset won't mess with my dirstack.
vit () {(
  if (( $# > 1 )); then
    unset DIRSTACKFILE
    cd $1; shift
  fi
  [[ "$#" = 1 ]] || { echo "Only one tag arg expected." >&2; return 1}
  # vi -t "$@"
  vi -c "tj $@"
  )}
alias vdf="vit ~df"
compdef -e 'if (( CURRENT > 3 )); then cd -q ${~words[2]} >/dev/null; fi; _complete_tag; if (( CURRENT > 3 )); then cd -q - >/dev/null; fi' vit
# }}}

# Restart network interface
ifrestart() {
  (( $# > 0 )) || { echo "Missing interface."; return 1; }
  if [[ $UID == 0 ]]; then
    ifdown $1
    ifup $1
  else
    sudo ifdown $1
    sudo ifup $1
  fi
}

multicat() {
  for file in $@; do
    echo "=== $file ==="
    cat $file
  done
}

# sudosession: start a session as another user (via sudo, default is root), {{{
# using a separate environment based on ~/.dotfiles (in ~/.sudosession).
# NOTE: while "sudo -s HOME=.. …" appears to work best, it failed
#       on a SUSE 10.4 system with "$SHELL: can't open input file: command".
sudosession() {
  emulate -L zsh
  local user=root
  while [[ $1 == -* ]] ; do
    case $1 in
      (-u) shift ; user=$1 ;;
      (--) shift ; break ;;
      (-h)
        printf 'usage: sudosession [-h|-u USER] <cmd>\n'
        printf '  -h      shows this help text.\n'
        printf '  -u      set specific user (default: root).\n'
        return 0
        ;;
      (*) printf "unkown option: '%s'\n" "$1" ; return 1 ;;
    esac
    shift
  done

  [[ $USER == $user ]] && { echo "Already $user."; return 1; }

  sudohome=$HOME/.sudosession/$user
  tempfile=$(mktemp -t sudosession.XXXXXX)
  chmod u+x $tempfile
  if [[ ! -d $sudohome ]]; then
    echo "Creating $sudohome..."
    mkdir -p $sudohome
    # Copy dotfiles repo from user home
    cp -a $HOME/.dotfiles $sudohome
    sudo chown -R $user:$user $sudohome
    cd $sudohome/.dotfiles
    # Install symlinks for dotfiles
    sudo env HOME=$sudohome make install_checkout
    cd $OLDPWD
  fi
  # Create temporary file to be executed
  echo -nE "/usr/bin/env HOME=$sudohome" > $tempfile
  # Keep special environment vars (like sudo's envkeep)
  # Experimental: keep original $PATH (required/useful to keep byobu from bootstrap-byobu in there)
  for i in SSH_AUTH_SOCK SSH_CONNECTION http_proxy https_proxy ftp_proxy no_proxy PATH; do
    echo -nE " $i='${(P)i}'" >> $tempfile
  done
  echo -nE " $SHELL" >> $tempfile
  if (( $#@ )); then
    # execute the command/arguments:
    # TODO: when using `-i` extra care should be taken to check for $PWD being the same!
    echo -E " -i -c '"${(q)*}"'" >> $tempfile
  fi
  echo "\ncommand rm \$0" >> $tempfile
  sudo chown $user $tempfile
  sudo -u $user $tempfile
}
alias rs=sudosession  # mnemonic: "root session"
compdef "_arguments '-u[user name]:user name:_users' '*::arguments: _normal'" sudosession
# }}}

# connect to qemu system by default
export VIRSH_DEFAULT_CONNECT_URI=qemu:///system


# Display "^C" when aborting zle
# XXX: behaves funny when aborting Ctrl-R
# Mikachu | well, you can set some private parameter when you enter isearch and unset it when you leave, and check for it in the trap
# Mikachu | ie, use the zle-isearch-exit and zle-isearch-update widgets
TRAPINT() { print -nP %F{red}%B\^C%f%b; return 1 }

alias map='xargs -n1 -r'

alias vimrc='vim ~df/vimrc'
alias zshrc='vim ~df/zshrc'

# autoload run-help helpers, e.g. run-help-git
local run_helpers
run_helpers=/usr/share/zsh/functions/Misc/run-help-*(N:t)
if [[ -n $run_helpers ]]; then
  autoload -U $run_helpers
fi


# Change to repository root (starting in parent directory), using the first
# entry of a recursive globbing.
RR() {
  setopt localoptions extendedglob
  local a
  # note: removed extraneous / ?!
  a=( (../)#.(git|hg|svn|bzr)(:h) )
  if (( $#a )); then
    cd $a[1]
  fi
}

# Call Makefile from parent directories, if there is no Makefile in the current
# dir and '-C'/'-f' is not used.
make () {
  if ! [ -f Makefile ] && ! (( ${@[(I)-f]} )) && ! (( ${@[(I)-C]} )); then
    setopt localoptions extendedglob
    local m
    m=((../)#Makefile(N))
    if (( $#m )); then
      echo -n "No Makefile in current dir. Use $m[1]? (y to continue) " >&2
      read -q && {
        echo
        command make -C $m[1]:h "$@"
        return
      }
      return
    fi
  fi
  command make "$@"
}


adbpush() {
  local i
  for i; do
    echo "Pushing $i to /sdcard/$i:t"
    adb push $i /sdcard/$i:t
  done
}

# Run the provided expression with `time`.
# The first arg can be a number of iterations (default 100).
timeit() {
  local expr iterations=100
  if [[ $1 = <-> ]]; then
    iterations=$1
    shift
  fi
  if [[ $# > 1 ]]; then
    expr=($@)
    expr=(${(q-)expr})
  else
    expr=(${(z)@})
  fi

  time ( for _ in {1..$iterations}; do
      eval $expr
    done )
}

zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

# Complete words from tmux pane(s) {{{1
# Source: http://blog.plenz.com/2012-01/zsh-complete-words-from-tmux-pane.html
# Gist: https://gist.github.com/blueyed/6856354
_tmux_pane_words() {
  local expl
  local -a w
  if [[ -z "$TMUX_PANE" ]]; then
    _message "not running inside tmux!"
    return 1
  fi

  # Based on vim-tmuxcomplete's splitwords function.
  # https://github.com/wellle/tmux-complete.vim/blob/master/sh/tmuxcomplete
  _tmux_capture_pane() {
    tmux capture-pane -J -p -S -100 $@ |
      # Remove "^C".
      sed 's/\^C\S*/ /g' |
      # copy lines and split words
      sed -e 'p;s/[^a-zA-Z0-9_]/ /g' |
      # split on spaces
      tr -s '[:space:]' '\n' |
      # remove surrounding non-word characters
      =grep -o "\w.*\w"
  }
  # Capture current pane first.
  w=( ${(u)=$(_tmux_capture_pane)} )
  echo $w > /tmp/w1
  local i
  for i in $(tmux list-panes -F '#D'); do
    # Skip current pane (handled before).
    [[ "$TMUX_PANE" = "$i" ]] && continue
    w+=( ${(u)=$(_tmux_capture_pane -t $i)} )
  done
  _wanted values expl 'words from current tmux pane' compadd -a w
}

zle -C tmux-pane-words-prefix   complete-word _generic
zle -C tmux-pane-words-anywhere complete-word _generic
bindkey '^X^Tt' tmux-pane-words-prefix
bindkey '^X^TT' tmux-pane-words-anywhere
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' completer _tmux_pane_words
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' ignore-line current
# Display the (interactive) menu on first execution of the hotkey.
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' menu yes select interactive
# zstyle ':completion:tmux-pane-words-anywhere:*' matcher-list 'b:=* m:{A-Za-z}={a-zA-Z}'
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' matcher-list 'b:=* m:{A-Za-z}={a-zA-Z}'
# }}}

# goodness from grml-etc-core {{{1
# http://git.grml.org/?p=grml-etc-core.git;a=summary

# creates an alias and precedes the command with
# sudo if $EUID is not zero.
salias() {
    emulate -L zsh
    local only=0 ; local multi=0
    while [[ $1 == -* ]] ; do
        case $1 in
            (-o) only=1 ;;
            (-a) multi=1 ;;
            (--) shift ; break ;;
            (-h)
                printf 'usage: salias [-h|-o|-a] <alias-expression>\n'
                printf '  -h      shows this help text.\n'
                printf '  -a      replace '\'' ; '\'' sequences with '\'' ; sudo '\''.\n'
                printf '          be careful using this option.\n'
                printf '  -o      only sets an alias if a preceding sudo would be needed.\n'
                return 0
                ;;
            (*) printf "unkown option: '%s'\n" "$1" ; return 1 ;;
        esac
        shift
    done

    if (( ${#argv} > 1 )) ; then
        printf 'Too many arguments %s\n' "${#argv}"
        return 1
    fi

    key="${1%%\=*}" ;  val="${1#*\=}"
    if (( EUID == 0 )) && (( only == 0 )); then
        alias -- "${key}=${val}"
    elif (( EUID > 0 )) ; then
        (( multi > 0 )) && val="${val// ; / ; sudo }"
        alias -- "${key}=sudo ${val}"
    fi

    return 0
}


# tlog/llog: tail/less /v/l/{syslog,messages} and use sudo if necessary
callwithsudoifnecessary_first() {
  cmd=$1; shift
  for file do
    # NOTE: `test -f` fails if the parent dir is not readable, e.g. /var/log/audit/audit.log
    # if [[ -f $file ]]; then
      if [[ -r $file ]]; then
        ${(Q)${(z)cmd}} $file
      elif [ "$UID" != 0 ] && [ -n "$commands[sudo]" ] ; then
        sudo ${(Q)${(z)cmd}} $file
      else
        continue
      fi
      return
    # fi
  done
}
# Call command ($1) with all arguments, and use sudo if any file argument is not readable
# This is useful for: `tf ~l/squid3/*.log`
callwithsudoifnecessary_all() {
  cmd=$1; shift

  if [ "$UID" != 0 ] && [ -n "$commands[sudo]" ] ; then
    for file do
      # NOTE: `test -f` fails if the parent dir is not readable, e.g. /var/log/audit/audit.log
      if ! [[ -r $file ]]; then
        sudo ${(Q)${(z)cmd}} "$@"
        return $?
      fi
    done
  fi
  # all readable:
  ${(Q)${(z)cmd}} "$@"
}
tlog() {
  callwithsudoifnecessary_first "tail -F" /var/log/syslog /var/log/messages
}
llog() {
  callwithsudoifnecessary_first less /var/log/syslog /var/log/messages
}
llog1() {
  callwithsudoifnecessary_first less /var/log/syslog.1 /var/log/messages.1
}
tf() {
  callwithsudoifnecessary_all "tail -F" "$@"
}
lf() {
  callwithsudoifnecessary_all less "$@"
}


# Generic aliases.
# NOTE: use 'function' explicitly in function definitions used in aliases.
# Otherwise the alias expansion would also define e.g. "noglob" as a function
# when resourcing zshrc.

# Display files sorted by size.
function dusch() {
  # setopt extendedglob bareglobqual
  du -sch -- ${~^@:-"*"}(ND) | sort -rh
}
alias dusch='noglob dusch'

function pip() {
  command pip "$@" && rehash
}

# Print host + cwd.
alias phwd='print -rP %M:%/'

alias dL='dpkg -L'
alias dS='dpkg -S'
# grep in the files of a package, e.g. `dG acpid screen`.
dG() {
  local i p
  p=$1; shift
  for i in $(dpkg -L $p); do
    test -f $i && grep -H $@ -- $i
  done
}

alias ag='ag --smart-case'


# Make aliases work with sudo; source: http://serverfault.com/a/178956/14449
# For handling functions (e.g. _nomatch) see http://www.zsh.org/mla/users/1999/msg00155.html.
alias sudo='sudo '

alias tignews='tig HEAD@{1}..HEAD@{0}'
alias tigin='tig ..@{u}'
alias tigfin='git fetch && tig ..@{u}'

viag() {
  (( $# )) || { echo "Usage: $0 <arguments to :Ag in vi>"; return 64 }
  vi -c "Ag $*"
}

vis() {
  # Open a session in vim.
  local session=$1; shift
  vi -c "SessionOpen $session" "$@"
}
compdef "compadd ~/.config/vim/sessions/*.vim(:t:r)" vis

# OpenVZ container: change to previous directory (via dirstack plugin) {{{1
if [[ -r /proc/user_beancounters ]] && [[ ! -d /proc/bc ]] && (( $plugins[(I)dirstack] )) && (( $#dirstack )); then
  popd
fi


# Incognito mode: do not store history and dirstack.
incognito() {
  if [[ $1 == -u ]]; then
    # Undo.
    [[ -z $_incognito_save_HISTFILE ]] && {
      echo "Nothing to undo."
      return 1
    }
    HISTFILE=$_incognito_save_HISTFILE
    DIRSTACKFILE=$_incognito_save_DIRSTACKFILE
    add-zsh-hook -d precmd  _zsh_persistent_history_precmd_hook
    unset _incognito_save_HISTFILE _incognito_save_DIRSTACKFILE
  elif [[ -n $_incognito_save_HISTFILE ]]; then
      echo "In incognito mode already!"
      return 1
  else
    _incognito_save_HISTFILE=$HISTFILE
    _incognito_save_DIRSTACKFILE=$DIRSTACKFILE
    unset HISTFILE
    DIRSTACKFILE=/dev/null
    add-zsh-hook -d precmd  _zsh_persistent_history_precmd_hook
  fi
}

# Setup https://github.com/clvv/fasd. {{{
# Based on prezto / fasd --init auto
if (( $+commands[fasd] )); then
  () {
    local cache_file=~/.cache/fasd-zsh.cache
    if [[ ${commands[fasd]} -nt $cache_file || ! -s $cache_file ]]; then
      fasd --init auto >! "$cache_file"
    fi
    source $cache_file

    bindkey '^X^A' fasd-complete    # C-x C-a to do fasd-complete (fils and directories)
    bindkey '^X^F' fasd-complete-f  # C-x C-f to do fasd-complete-f (only files)
    bindkey '^X^D' fasd-complete-d  # C-x C-d to do fasd-complete-d (only directories)
  }
fi  # }}}

# Misc {{{1
# Minimal prompt: useful when creating a test case for copy'n'paste.
_zsh_minimalprompt_preexec() {
  # XXX: workaround $2 having a trailing space with assignments.
  if [[ "$1" != "$2" ]] && [[ "$1 " != "$2" ]]; then
    echo " >> $3"
  fi
  # _zsh_minimalprompt_preexec_cmd=$2
}
minimalprompt() {
  if [[ $1 == -u ]]; then
    # Undo.
    add-zsh-hook -d preexec _zsh_minimalprompt_preexec
    setup_prompt_blueyed
  else
    unsetup_prompt_blueyed
    add-zsh-hook preexec _zsh_minimalprompt_preexec
    PS1="%~ %# "
  fi
}

# Update tty information for gpg-agent.
if [[ ${(t)GPG_TTY} == *-export ]]; then
  export GPG_TTY=$(tty)
  gpg-connect-agent UPDATESTARTUPTTY /bye >/dev/null
fi

# Source zsh-syntax-highlighting when not in Vim's shell.
if [[ -z $VIM ]]; then
  # NOTE: not 'cursor', which defaults to 'standout' and messes with vicmd mode.
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
  () {
    local f
    for f in /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
        ~/.dotfiles/lib/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
      if [[ -f $f ]]; then
        source $f; break
      fi
    done
  }
fi


# Add hook to adjust settings for slow dirs (e.g. ~/.gvfs/mtp/…)
autoload -U add-zsh-hook
# TODO: merge with _zshrc_vcs_check_for_changes_hook
_zsh_chpwd_handle_slow_dirs() {
  # if [[ $PWD == /run/user/*/gvfs/* ]] || [[ $PWD == ~/.gvfs/mtp/* ]]; then
  if (( $ZSH_IS_SLOW_DIR )); then
    ZSH_DISABLE_VCS_INFO=1
    (( $ZSH_DISABLE_HIGHLIGHT )) || ZSH_HIGHLIGHT_MAXLENGTH=0
  else
    ZSH_DISABLE_VCS_INFO=0
    (( $ZSH_DISABLE_HIGHLIGHT )) || ZSH_HIGHLIGHT_MAXLENGTH=300
  fi
}
add-zsh-hook chpwd _zsh_chpwd_handle_slow_dirs 2>/dev/null || {
  echo 'zsh-syntax-highlighting: failed loading add-zsh-hook.' >&2
}
zsh_disable_highlighting() {
  local v=${1=1}
  ZSH_DISABLE_HIGHLIGHT=$v
  ZSH_HIGHLIGHT_MAXLENGTH=$(($v ? 0 : 300))
}


# Make git-checkout completion less verbose with empty prefix/suffix.
zstyle -e ':completion:*:git-checkout:*' tag-order '
  if [[ -z $PREFIX$SUFFIX ]]; then
    reply=("! commit-tags heads-remote remote-branch-names remote-branch-names-noprefix")
  else
    reply=()
  fi'

# Zsh/Vim fg back-and-forth (I am using C-y in Vim, instead of C-z). {{{
# Ctrl-Z does fg<enter>
# via http://git.grml.org/?p=grml-etc-core.git;a=blob_plain;f=etc/zsh/zshrc;hb=HEAD
function grml-zsh-fg() {
  if (( ${#jobstates} )); then
    zle .push-input
    [[ -o hist_ignore_space ]] && BUFFER=' ' || BUFFER=''
    BUFFER="${BUFFER}fg %vi || fg"
    zle .accept-line
  else
    zle -M 'No background jobs. Doing nothing.'
  fi
}
zle -N grml-zsh-fg
bindkey '^z' grml-zsh-fg
bindkey '^y' grml-zsh-fg
# }}}

# Lookup in `man zshall`
zman() {
  PAGER="less -g -s '+/^       "$1"'" man zshall
}

# dquilt: quilt for Debian/Ubuntu packages.
dquilt() {
  quilt --quiltrc=${HOME}/.quiltrc-dpkg "$@"
}
compdef _quilt dquilt=quilt


# Disable XON/XOFF flow control; this is required to make C-s work in Vim.
# NOTE: silence possible error when using mosh:
#       "stty: standard input: Inappropriate ioctl for device"
# NOTE: moved to ~/.zshrc (from ~/.zshenv), to fix display issues during Vim
# startup (with subshell/system call).
stty -ixon 2>/dev/null


# Use the same file for enter/leave.
AUTOENV_FILE_LEAVE=.autoenv.zsh
source ~/.dotfiles/lib/zsh-autoenv/autoenv.zsh

# Lazily setup pyenv, if there's a .python-version file in the current dir.
_pyenv_lazy_load() {
  if (( $+functions[zsh_setup_pyenv] )); then
    if [[ -f $PWD/.python-version ]]; then
      zsh_setup_pyenv
    else
      return
    fi
  fi
  add-zsh-hook -d chpwd _pyenv_lazy_load
}
add-zsh-hook chpwd _pyenv_lazy_load

# Verbose completion.
# Source: http://www.linux-mag.com/id/1106/
# zstyle ':completion:*' verbose yes
# zstyle ':completion:*:descriptions' format '%B%d%b'
# zstyle ':completion:*:messages' format '%d'
# zstyle ':completion:*:warnings' format 'No matches for: %d'
# zstyle ':completion:*' group-name ''

# Provide hosts from ~/.pgpass for PostgreSQL completion.
zstyle -e ':completion::complete:(pg_*|psql):*' hosts 'reply=($(sed "s/:.*//" ~/.pgpass))'

# Directories {{{
# Changing/making/removing directory
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

alias md='mkdir -p'
alias rd=rmdir
alias d='dirs -v | head -10'

# mkdir & cd to it
function mcd() {
  mkdir -p "$1" && cd "$1"
}
compdef mcd=mkdir
# }}}

# misc {{{
## smart urls
autoload -U url-quote-magic
zle -N self-insert url-quote-magic

## jobs
setopt long_list_jobs

# Allow for comments after '#' with interactive shells.
setopt interactivecomments

## pager
export PAGER="less"

# only define LC_CTYPE if undefined
if [[ -z "$LC_CTYPE" && -z "$LC_ALL" ]]; then
        export LC_CTYPE=${LANG%%:*} # pick the first entry from LANG
fi
# }}}

# Settings for Debian/Ubuntu.
export DEBFULLNAME='Daniel Hahler'
export DEBEMAIL='ubuntu@thequod.de'


reloadzsh() {
  if [[ -n $jobstates ]]; then
    echo 'Running jobs, aborting..'; return 1
  fi

  # Delete widgets to avoid recursion error via zsh-syntax-highlighting.
  zle -D zle-keymap-select
  zle -D zle-line-finish
  zle -D zle-line-init

  # Hide assert.
  if (( $+functions[zsh_setup_pyenv] )); then
    unfunction zsh_setup_pyenv
  fi

  # XXX: re-sourcing zshrc mocks with display: putting "reset" before is also problematic.
  source ~/.zshenv
  ZSHRC_EXEC_COMMAND= source ~/.zshrc
}

# CDPATH: only for interactive shells, and do not export it.
typeset -U cdpath
cdpath=(~/projects ~/src ~/Vcs ~/.dotfiles/vim/plugged ~/.dotfiles/vim/neobundles ~/.dotfiles/lib)
# For AUR builds in Arch Linux.
[[ -d ~/builds ]] && cdpath+=(~/builds)

# Source local rc file if any.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Change to previous dir (requires dirstack), but not for login shells.
if ! (( $+ZSH_NO_CD_DASH )) && ! [[ -o login ]] && ! (( $+TMUX )); then
  [[ -d $OLDPWD ]] && cd $OLDPWD
fi

# Arch Linux / pacman.
if (( $+commands[pacman] )); then
  () {
    local cmd sudocmd
    if (( $+commands[pacaur] )); then
      cmd=pacaur
      sudocmd=(pacaur)
    else
      cmd=pacman
      sudocmd=(sudo pacman)
    fi

    alias pm=$sudocmd
    alias pmQ="$cmd -Q"
    alias pmQi="$cmd -Qi"
    alias pmQl="$cmd -Ql"
    alias pmQo="$cmd -Qo"
    alias pmRs="$cmd -Rs"
    eval "pmS() {$sudocmd -S \"\$@\" && rehash}"
    compdef -e "words=($sudocmd -S \"\${(@)words[2,-1]}\"); ((CURRENT+=$(($#sudocmd)))); _normal" pmS
    alias pmSi="$cmd -Qi"
    # search.
    alias pms="$cmd -Ss"

    alias pmup="pmS -yu --devel --needed"
  }
fi

# zsh_stop_debug_xtrace

true # return code 0

# vim: foldlevel=0
