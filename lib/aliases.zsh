# Push and pop directories on directory stack
alias pu='pushd'
alias po='popd'


# Super user
alias _='sudo'
alias please='sudo'

# ps + grep.
psgrep() {
  local i pids line
  # Add numeric args as pids.
  typeset -a args patterns
  for i do
    if [[ $i == <-> ]]; then
      pids=($i $pids)
      patterns+=($i)
    else
      args+=($i)
    fi
    shift
  done
  if (( $#args == 1 )); then
    pids+=($(pgrep -f $i))
    patterns+=($i)
  else
    for i in $args; do
      if ! [[ $i == -* ]]; then
        patterns+=($i)
      fi
    done
  fi
  if [[ -z $pids ]]; then
    echo "No processes found." >&2
    return 1
  fi
  output=(${(f):-"$(ps -fp ${=pids})"})
  if [[ -t 1 ]]; then
    colored=$(echo ${(F)output} | \grep --color=always ${^:--e"$patterns"} -e '^')
    echo "$colored" | LESS= less -R -X --quit-if-one-screen
  else
    ps -fp $pids
  fi
}

# Show history
if [ "$HIST_STAMPS" = "mm/dd/yyyy" ]
then
    alias history='fc -fl 1'
elif [ "$HIST_STAMPS" = "dd.mm.yyyy" ]
then
    alias history='fc -El 1'
elif [ "$HIST_STAMPS" = "yyyy-mm-dd" ]
then
    alias history='fc -il 1'
else
    alias history='fc -l 1'
fi
# List direcory contents
alias lsa='ls -lah'
alias l='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'

alias afind='ack-grep -il'

# "fast find in current dir": filter out any hidden directories
ffind() {
  local debug=0
  if [[ $1 == '-d' ]]; then
    debug=1
    set -x
    shift
  fi
  # Get options for `find`.
  opts=(-H)
  while true; do
    case $1 in
      -H|-L|-P|-O*) opts+=($1); shift ;;
      -D)  opts+=($1 $2); shift 2 ;;
      *) break ;;
    esac
  done
  # If the first argument is a dir, use it as base, but only
  # if there are more arguments or it starts with slash or dot.
  if [[ -d $1 ]] && ( [[ $# -gt 1 ]] || [[ $1 == [./]* ]] ) ; then
    dir=$1; shift
    (( $debug )) && echo "DEBUG: finding in $dir" >&2
  else
    dir=.
  fi

  args=()
  _has_cmd=0
  # Use '-iname' (as wildcard) by default, if there is one (non-dir/non-command) argument
  if (( $# > 0 )) && [[ $1 != -* ]]; then
    if (( $# == 1 )) ; then
      args=(-iname "*$1*" -print)
    else
      args=(-iname "*$1*" ${@:2})
    fi
  else
    args=($@)
  fi

  # if (( $# > 1 )) && [[ $_has_cmd == 0 ]]; then
  #   for arg ; do
  #     if [[ $arg == -* ]]; then
  #       _has_cmd=1
  #       break
  #     fi
  #   done
  #   [[ $_has_cmd == 0 ]] && args+=(-print)
  # fi
  # If args are empty, use -print (use case: find every file, but hidden ones)
  if [[ $#args == 0 ]]; then
    args=(-print)
  elif [[ $args[$#args] != -* ]]; then
    # no command as last arg: use print
    args+=(-print)
  fi
  (( $debug )) && echo "DEBUG: args: $args ($#args)" >&2
  # -H: resolve symlinks from arguments.
  # -mindepth 1: do not prune arguments, so that `ffind ~/.vim` works.
  # NOTE: action before pruning, so that you can search for e.g. "bower_components".
  cmd=(find $opts $dir -mindepth 1
      \( ! -name '*.pyc' ! -regex '.*\.sw[po]' \)
      -a \( $args \) -o \(
      \( -type d -name ".*" \)
      -o \( -type d -name __pycache__ \)
      -o \( -type d -name _build \)
      -o \( -type d -name node_modules \)
      -o \( -type d -name bower_components \)
    \) -prune)
  # cmd=(find $dir \( ${args} \))
  (( $debug )) && echo "DEBUG: cmd:  ${(Q)${(z)cmd}}" >&2
  $cmd
}

# ls
LS_OPTIONS=(--color=auto -h -F)
# TODO: lazily determine this on first call to ls?  See lib/grep.zsh (_setup_grep_alias).
if command ls --help 2>&1|grep -q -- --hide; then
  LS_OPTIONS+=(--hide='*.pyc')
fi
alias ls='ls ${LS_OPTIONS}'
alias l='ls'
alias la='ls -a'
alias ll='ls -l'
alias lla='ll -a'
alias lll='lla --color | less -R'
lth() { ll --color -t "$@" | head -n $((LINES > 23 ? 20 : LINES-3)) }
lsh() { l  --color -t "$@" | head -n $((LINES > 23 ? 20 : LINES-3)) }

# commands starting with % for pasting from web
alias %=' '

# Custom aliases (from ~/.bash_aliases)
# Get previous ubuntu version from changelog (the one to use with -v for e.g. debuild)
alias debverprevubuntu="dpkg-parsechangelog --format rfc822 --count 1000 | grep '^Version: ' | grep ubuntu | head -n2 | tail -n1 | sed 's/^Version: //'"
# Sponsored debuild
alias sdebuild='debuild -S -k3FE63E00 -v$(debverprevubuntu)'
alias bts='DEBEMAIL=debian-bugs@thequod.de bts --sendmail "/usr/sbin/sendmail -f$DEBEMAIL -t"'
# alias m=less

# xgrep: grep with extra (excluding) options
xgrep() {
  _xgrep_cmd_local_extra_opts=(-maxdepth 0)
  xrgrep "$@"
  unset _xgrep_cmd_local_extra_opts
}
# xrgrep: recursive xgrep, path is optional (defaults to current dir)
xrgrep() {
  # Get grep pattern and find's path from args
  # Any options are being passed to grep.
  local inopts findpath grepopts greppattern debug
  debug=0
  inopts=1
  findpath=() # init appears to be required to prevent leading space from "$findpath" passed to `find`
  for i in "$@"; do
    if [[ $i == '--' ]]; then inopts=0
    elif [[ $inopts == 0 ]] || [[ $i != -* ]]; then
      if [[ -z $greppattern ]]; then
        greppattern=$i
      else
        findpath+=($i)
      fi
    else
      if [[ $i == '--debug' ]]; then
        debug=1
      else
        grepopts+=($i)
      fi
    fi
  done
  [[ -z $findpath ]] && findpath=('.')

  # echo "findpath: $findpath" ; echo "grepopts: $grepopts" ; echo "greppattern: $greppattern"

  # build command to use once
  if [[ -z $_xgrep_cmd ]] ; then
    _xgrep_exclude_dirs=(CVS .svn .bzr .git .hg .evocache media asset cache) # "media, asset, cache" with betterplace (tb)
    _xgrep_exclude_exts=(avi mp gif gz jpeg jpg JPG png pptx rar swf sw\? tif wma xls xlsx zip) # sw?=vim swap files
    _xgrep_exclude_files=(tags)

    if [[ -n $_xgrep_cmd_local_extra_opts ]]; then
      _xgrep_cmd=($_xgrep_cmd_local_extra_opts)
    else
      _xgrep_cmd=()
    fi

    _xgrep_cmd+=(-xdev -type d \()
    _xgrep_cmd+=(-name ${(pj: -o -name :)_xgrep_exclude_dirs})
    _xgrep_cmd+=(\) -prune)

    _xgrep_cmd+=(-o -type f \()
    _xgrep_cmd+=(-name \*.${(pj: -o -name *.:)_xgrep_exclude_exts})
    _xgrep_cmd+=(\) -prune)

    _xgrep_cmd+=(-o -type f \()
    _xgrep_cmd+=(-name ${(pj: -o -name :)_xgrep_exclude_files})
    _xgrep_cmd+=(\) -prune)

    _xgrep_cmd+=(-o -type f -print0)
  fi
  _findcmd=(find -L $findpath $=_xgrep_cmd)
  _xargscmd=(xargs -0 -r grep -e "$greppattern" $grepopts)
  if (( $debug )) ; then
    echo "greppattern: $greppattern" >&2
    echo "grepopts   : $grepopts" >&2
    # escape _findcmd to be copy'n'pastable
    echo "_findcmd   : ${${${_findcmd//\(/\\(}//)/\\)}//\*/\\*}" >&2
    echo "_xargscmd  : $_xargscmd" >&2
  fi
  $=_findcmd | $_xargscmd
}
function o() {
  if (( $# > 1 )); then
    echo -n "Open multiple files? [yn] "
    read -q || return
    echo
  fi
  if [ $commands[xdg-open] ]; then
    for f; do
      xdg-open "$f"
    done
  else
    for f; do
      open "$f" # MacOS
    done
  fi
}
alias 7zpwd="7z a -mx0 -mhe=on -p"
alias lh="ls -alt | head"


# List directory contents
# via http://github.com/sjl/oh-my-zsh/blob/968aaf26271d6a88841c4204389eccd8eac8010e/lib/directories.zsh
alias l1='tree --dirsfirst -ChFL 1'
alias l2='tree --dirsfirst -ChFL 2'
alias l3='tree --dirsfirst -ChFL 3'
alias ll1='tree --dirsfirst -ChFupDaL 1'
alias ll2='tree --dirsfirst -ChFupDaL 2'
alias ll3='tree --dirsfirst -ChFupDaL 3'

# wget + patch
wpatch() {
  PATCH_URL="$1"; shift
  wget $PATCH_URL -O- | zless | patch -p1 "$@"
}
wless() {
  zless =(wget -q "$@" -O-)
}
# auto ssh-add key
# (use a function to allow for setting temp. environment, e.g. `FOO=bar ssh`)
ssh() {
  if ! ssh-add -l >/dev/null 2>&1; then
    ssh-add
  fi
  command ssh "$@"
}

# Make (overwriting) file operations interactive by default.
alias cp="cp -i"
alias mv="mv -i"

c() {
  local prev=$PWD
  [[ -d "$@" ]] && cd "$@" || j "$@"
  [[ $PWD != $prev ]] && ls
}
mdc() { mkdir "$@" && cd "$1" }

# verynice: wrap with ionice (if possible) and "nice -n19" {{{
_verynice_ionice_cmd=
get_verynice_cmd() {
  if [[ -z $_verynice_ionice_cmd && -x ${commands[ionice]} ]]; then
    _verynice_ionice_cmd="ionice -c3" && $=_verynice_ionice_cmd true 2>/dev/null \
    || ( _verynice_ionice_cmd="ionice -c2 -n7" && $=_verynice_ionice_cmd true 2>/dev/null ) \
    || _verynice_ionice_cmd=
  fi
}
verynice() {
  get_verynice_cmd
  nice -n 19 $=_verynice_ionice_cmd $@
}
veryrenice() {
  get_verynice_cmd
  $=_verynice_ionice_cmd -p $@
  renice 19 $@
}
# }}}

# Mercurial
alias hgu="hg pull -u"
alias hgl="hg log -G" # -G via graphlog extension
alias hgd="hg diff"
alias hgc="hg commit"

if [ $commands[screen] ]; then
screen() {
  local term=$TERM
  if [ "$TERM" = rxvt-unicode-256color ]; then
    term=rxvt-256color
    echo "Working around screen bug #30880, using TERM=$term.." # http://savannah.gnu.org/bugs/?30880
    sleep 2
  fi
  if [ -x /usr/bin/tput ] && [ $(/usr/bin/tput colors 2>/dev/null || echo 0) -eq 256 ]; then
    # ~/.terminfo ships s/screen-256color.
    TERM=$term command screen -T screen-256color "$@"
  else
    TERM=$term command screen "$@"
  fi
}
fi

# Systemd.
if (( $+commands[systemctl] )); then
  alias sc=systemctl
  alias scu='systemctl --user'
  if [[ $UID = 0 ]]; then
    alias ssc='systemctl'
  else
    alias ssc='sudo systemctl'
  fi
  alias jc='journalctl'
  alias jcu='journalctl --user'
  alias jxe='journalctl -x -e -nall'
  alias jxf='journalctl -x -e -f'
  alias jcs='journalctl --system'
fi

# Colored cat/less.
alias ccat='pygmentize -g'
cless() {
  pygmentize -g "$@" | less
}

alias idn='idn --quiet'
