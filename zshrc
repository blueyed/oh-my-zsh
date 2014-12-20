# TODO: trap on Ctrl-D / exit if there are stashed changes in a directory (similar to background processes)
#       (similar to CHECK_JOBS)
# TODO: alias/function to trash a file (mv it to ~/.local/share/Trash/…)
#
# NOTE: $path adjustment is done in .zshenv

# # Skip this, if in a subshell (e.g. in tmux)
# if [[ -n $SHLVL ]] && [[ $SHLVL > 1 ]]; then
#   return
# fi

# Path to your oh-my-zsh configuration.
export ZSH=$HOME/.oh-my-zsh

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
# NOTE: pip used from zsh-completions, but has no support for packages (https://github.com/zsh-users/zsh-completions/issues/194)
plugins=(git github dirstack svn apt grunt)

# grunt-zsh-completion
zstyle ':completion::complete:grunt::options:' show_grunt_path yes

fpath=(~/.dotfiles/lib/zsh-completions/src $fpath)
fpath=(~/.dotfiles/lib/docker-zsh-completion $fpath)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...

REPORTTIME=10 # print elapsed time when more than 10 seconds

setopt MAIL_WARNING
setopt HIST_IGNORE_SPACE # Ignore commands with leading space

setopt MARK_DIRS # Append a trailing `/' to all directory names resulting from filename generation (globbing).

setopt NUMERIC_GLOB_SORT
setopt EXTENDED_GLOB

# hows about arrays be awesome?  (that is, frew${cool}frew has frew surrounding all the variables, not just first and last
setopt RC_EXPAND_PARAM

setopt PUSHD_SILENT # make popd quiet

setopt CORRECT # do not use CORRECT_ALL

export RI="--format ansi"


# directory based VCS before repo based ones (e.g. CVS in $HOME, the latter using Git)
# zstyle ':vcs_info:*' enable cvs svn bzr hg git
zstyle ':vcs_info:*' enable hg bzr git
# zstyle ':vcs_info:bzr:*' use-simple true
zstyle ':vcs_info:(hg|svn):*' use-simple false
zstyle ':vcs_info:(bzr|hg|svn):*' use-simple true
zstyle ':vcs_info:*:prompt:*' hgrevformat '%r'

# check-for-changes can be really slow.
# Enable it depending on the current dir's filesystem type.
autoload -U add-zsh-hook

# Set ZSH_IS_SLOW_DIR
add-zsh-hook chpwd _zshrc_chpwd_detect_slow_dir 2>/dev/null || {
  echo 'zsh-syntax-highlighting: failed loading add-zsh-hook.' >&2
}
_is_slow_file_system() {
  df_T=$(df -T . 2>/dev/null)
  if [[ $df_T == '' ]]; then
    # 'df -T' might not be available (busybox, diskstation).
    # 'stat -f' does not detect cifs (type UNKNOWN).
    # fs_type=$(stat -f . | grep -o 'Type:.*' | cut -f2 -d\ )
    mount_point="$(df . | awk 'END {print $NF}')"
    fs_type=$(mount | awk '$3 == "'$mount_point'" { print $5 }')
  else
    fs_type$(echo $df_T|tail -n1|tr -s ' '|cut -f2 -d\  2>/dev/null)
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
# see also lib/wordnav.zsh
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

# autojump
source ~/.dotfiles/autojump/bin/autojump.zsh
# XXX: _j() has been removed in autojump!?! commit 49a0d70
# fpath=(~/.dotfiles/autojump/bin $fpath)
# Obsolete with master.
export AUTOJUMP_KEEP_SYMLINKS=1

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
if [ -n "$commands[vzctl]" ] ; then
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

# named directories/shortcuts (~l => /var/log)
# local ones in ~/.zshrc.local
hash -d l=/var/log
hash -d d=~/Downloads
hash -d df=~/.dotfiles
hash -d omz=~/.dotfiles/oh-my-zsh

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

# Completion for custom docker scripts.
compdef _docker docker-shell=_docker_containers

# Export COLORTERM as LC_MY_SSH_COLORTERM, to be passed on through ssh, via
# SendEnv in ~/.ssh/config and LC_* whitelist on the server.
# NOTE: "AcceptEnv" is empty by default, useful: "LANG LC_*"
if (( $+COLORTERM )) && ! (( $+LC_MY_SSH_COLORTERM )); then
  export LC_MY_SSH_COLORTERM=$COLORTERM
elif [[ -n $SSH_CLIENT ]]; then
  if ! (( $+COLORTERM )) && [[ -n $LC_MY_SSH_COLORTERM ]]; then
    export COLORTERM=$LC_MY_SSH_COLORTERM
  fi
fi

# Assume 256 colors with xterm/screen when $DISPLAY or $COLORTERM is given.
if [[ -n $DISPLAY ]] || [[ -n $COLORTERM ]] || [[ -n $SSH_CLIENT ]]; then
  if [[ $TERM == "xterm" ]]; then
    export TERM=xterm-256color
  elif [[ $TERM == "screen" ]]; then
    export TERM=screen-256color
  fi
fi

# Use custom screen-*-it terminfo (from ~/.terminfo), with fixed italics/standout for tmux.
if [[ $TERM = screen* ]] && (( $+TMUX )) && ! [[ $TERM = *-it ]]; then
  TERM=$TERM-it
fi

# Fix up TERM if there's no info for the currently set one (might cause programs to fail)
if ! tput longname &> /dev/null; then
  echo "tput longname failed, setting fallback TERM:"
  set -x
  if [[ $TERM == screen*bce ]]; then TERM=screen-bce
  elif [[ $TERM == screen* ]]; then TERM=screen
  else TERM=xterm fi
  export TERM
  set +x
fi

setopt GLOB_COMPLETE # helps with "setopt *alias<tab>" at least

# Setup vimpager as pager:
# NOTE: quite a few drawbacks: load time, usability (not less, not Vim, …)
# export PAGER=~/.dotfiles/lib/vimpager/vimpager
# alias less=$PAGER
# alias zless=$PAGER

# use full blown vim always
if [ "$commands[(I)vim]" ]; then
  alias vi=vim
fi

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
  for i in SSH_AUTH_SOCK SSH_CLIENT http_proxy https_proxy ftp_proxy no_proxy PATH; do
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

# Special treatment for verdi4u machines
# WARNING: '-f' might be slow!!
# if [[ $(hostname -f 2>/dev/null) = *.verdi4u.de ]]; then
#   # Get recent python into $PATH for autojump
#   # (the first python from /opt != 2.4/2.5)
#   if [[ $(python -V 2>&1) = Python\ 2.[45]* ]]; then
#     for i in /opt/python /opt/py*(/) ; do
#       i=${i%/}
#       test -f $i/bin/python || continue
#       if [[ $($i/bin/python -V 2>&1 ) != Python\ 2.[45]* ]]; then
#         path=($i/bin $path)
#         break
#       fi
#     done
#   fi
# fi

# autoload $ZSH/functions/*(:t)

# Display "^C" when aborting zle
# XXX: behaves funny when aborting Ctrl-R
# Mikachu | well, you can set some private parameter when you enter isearch and unset it when you leave, and check for it in the trap
# Mikachu | ie, use the zle-isearch-exit and zle-isearch-update widgets
TRAPINT() { print -nP %F{red}%B\^C%f%b; return 1 }

# exit zsh like vim
alias :q=exit
alias ZZ=exit

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

# Call Makefile from parent directories.
make () {
  if ! [ -f Makefile ]; then
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
  for i; do
    echo "Pushing $i to /sdcard/$i:t"
    adb push $i /sdcard/$i:t
  done
}

# complete words from tmux pane(s) {{{1
# Source: http://blog.plenz.com/2012-01/zsh-complete-words-from-tmux-pane.html
# Gist: https://gist.github.com/blueyed/6856354
_tmux_pane_words() {
  local expl
  local -a w
  if [[ -z "$TMUX_PANE" ]]; then
    _message "not running inside tmux!"
    return 1
  fi
  # capture current pane first
  w=( ${(u)=$(tmux capture-pane -J -p)} )
  for i in $(tmux list-panes -F '#P'); do
    # skip current pane (handled above)
    [[ "$TMUX_PANE" = "$i" ]] && continue
    # TODO: split words: e.g. "foo(bar" should be "foo" and "bar".
    w+=( ${(u)=$(tmux capture-pane -J -p -t $i)} )
  done
  _wanted values expl 'words from current tmux pane' compadd -a w
}

zle -C tmux-pane-words-prefix   complete-word _generic
zle -C tmux-pane-words-anywhere complete-word _generic
bindkey '^X^Tt' tmux-pane-words-prefix
bindkey '^X^TT' tmux-pane-words-anywhere
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' completer _tmux_pane_words
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' ignore-line current
# display the (interactive) menu on first execution of the hotkey
zstyle ':completion:tmux-pane-words-(prefix|anywhere):*' menu yes select interactive
zstyle ':completion:tmux-pane-words-anywhere:*' matcher-list 'b:=* m:{A-Za-z}={a-zA-Z}'
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


# Generic aliases
# Display files sorted by size
dusch() {
  # setopt extendedglob bareglobqual
  du -sch -- ${~^@:-"*"}(D) | sort -rh
}
alias dusch='noglob dusch'
alias pip='noglob pip'
alias spip='noglob sudo pip'
alias phwd='print -rP %M:%/'

alias dL='dpkg -L'
alias dS='dpkg -S'
# grep in the files of a package, e.g. `dG acpid screen`.
dG() { p=$1; shift; for i in $(dpkg -L $p); test -f $i && grep -H $@ -- $i }

# Custom command modifier to not error on non-matches; similar to `noglob`.
_nomatch () {
  setopt localoptions nonomatch
  local cmd=$1; shift
  # NOTE: not using 'command' to make it work with functions.
  # NOTE: quotes required with 'cmd foo: (bar)'
  # command $cmd ${~@}
  $cmd "${~@}"
}
compdef _precommand _nomatch
alias ag='_nomatch ag --smart-case'


# Make aliases work with sudo; source: http://serverfault.com/a/178956/14449
# For handling functions (e.g. _nomatch) see http://www.zsh.org/mla/users/1999/msg00155.html.
alias sudo='sudo '

viack() {
  vi -c "Ack $*"
}
viag() {
  vi -c "Ag $*"
}


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
    add-zsh-hook -d preexec autojump_preexec
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
    add-zsh-hook -d preexec autojump_preexec
    add-zsh-hook -d precmd  _zsh_persistent_history_precmd_hook
  fi
}

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

export GPG_TTY=$(tty)


# Source zsh-syntax-highlighting when not in Vim's shell
if [[ -z $VIM ]]; then
  # https://github.com/zsh-users/zsh-syntax-highlighting#readme
  # NOTE: not 'cursor', which defaults to 'standout' and messes with vicmd mode.
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
  #ZSH_HIGHLIGHT_HIGHLIGHTERS+=(root)
  # XXX: slow?!
  source ~/.dotfiles/lib/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
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


# if [[ $TERM == xterm* ]]; then
  # not for "linux"
  # might use "tput colors"
  # ~/.vim/bundle/colorscheme-gruvbox/gruvbox_256palette.sh
  export BASE16_SHELL_DIR=~/.dotfiles/lib/base16/base16-shell
  base16_scheme() {
    if [[ -n $1 ]]; then
      export BASE16_SCHEME=$1
    else
      echo "Reloading $BASE16_SCHEME..."
    fi
    local base16_scheme_file=$BASE16_SHELL_DIR/base16-$BASE16_SCHEME.sh
    echo "Loading $BASE16_SCHEME..."
    [[ -s $base16_scheme_file ]] && source $base16_scheme_file
  }
  # completion for base16_scheme function
  compdef "compadd $BASE16_SHELL_DIR/*.sh(:t:r:s/base16-/)" base16_scheme

  # init/load solarized theme
  # XXX: do not do so, when using a non-base16 vim color theme (e.g. jellybeans)
  # This changes color16, which is used as bg for SearchHl
  # base16_scheme solarized.dark
# fi


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


AUTOENV_FILE_LEAVE=.env
AUTOENV_LOOK_UPWARDS=1
source ~/.dotfiles/lib/zsh-autoenv/autoenv.zsh


# Source local rc file if any {{{1
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# zsh_stop_debug_xtrace

true # return code 0

# vim: foldlevel=0
