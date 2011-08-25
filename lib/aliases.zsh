# Push and pop directories on directory stack
alias pu='pushd'
alias po='popd'


# Super user
alias _='sudo'

#alias g='grep -in'

# Show history
alias history='fc -l 1'

# List direcory contents
alias lsa='ls -lah'
alias l='ls -la'
alias ll='ls -l'
alias sl=ls # often screw this up

alias afind='ack-grep -il'

# "fast find": filter out any dotfiles
alias ffind='find -mindepth 1 -name ".*" -prune'

alias x=extract


# ls
export LS_OPTIONS='--color=auto -h'
alias ls='ls ${=LS_OPTIONS}'
alias l='ls ${=LS_OPTIONS} -F'
alias la='ls ${=LS_OPTIONS} -aF'
alias ll='ls ${=LS_OPTIONS} -lF'
alias lla='ls ${=LS_OPTIONS} -laF'
alias lll='ll -a --color | less -R'
lth() {
	ll -t "$@" | head
}

# commands starting with % for pasting from web
alias %=' '

alias g='gvim --remote-silent'

# Custom aliases (from ~/.bash_aliases)
# Get previous ubuntu version from changelog (the one to use with -v for e.g. debuild)
alias debverprevubuntu="dpkg-parsechangelog --format rfc822 --count 1000 | grep '^Version: ' | grep ubuntu | head -n2 | tail -n1 | sed 's/^Version: //'"
# Sponsored debuild
alias sdebuild='debuild -S -k3FE63E00 -v$(debverprevubuntu)'
alias bts='DEBEMAIL=debian-bugs@thequod.de bts --sendmail "/usr/sbin/sendmail -f$DEBEMAIL -t"'
# alias m=less
xgrep() {
  # build command to use once ("--exclude-dir" might not be supported)
  if [[ -z $_xgrep_cmd ]] ; then
    _xgrep_cmd=(grep)
    if command grep --help | command grep -q exclude-dir ; then
      _xgrep_cmd+=(--exclude-dir=CVS --exclude-dir=.svn --exclude-dir=.bzr --exclude-dir=.git --exclude-dir=.hG)
    fi
  fi
  $=_xgrep_cmd $@
}
# xrgrep: recursive xgrep, path is optional (defaults to current dir)
xrgrep() {
	# Get number of (non-option) args: for args >= 2 we do not use the default dir.
	local nbargs=0 inopts=1 dir=.
	for i in $@; do
		if [[ $i == '--' ]]; then inopts=0
		elif [[ $inopts == 0 ]] || [[ $i != -* ]]; then ((nbargs++))
		fi
		if (( nbargs >= 2 )); then
			dir=
			break
		fi
	done
	xgrep -R $@ ${dir:-}
}
alias connect-to-moby='ssh -t hahler.de "while true ; do su -c \"screen -x byobu || { sleep 2 && byobu -S byobu }\" && break; done"'
alias o=xdg-open
alias 7zpwd="7z a -mx0 -mhe=on -p"
alias ag="ack-grep"
alias lh="ls -alt | head"


# List directory contents
# via http://github.com/sjl/oh-my-zsh/blob/968aaf26271d6a88841c4204389eccd8eac8010e/lib/directories.zsh
alias l1='tree --dirsfirst -ChFL 1'
alias l2='tree --dirsfirst -ChFL 2'
alias l3='tree --dirsfirst -ChFL 3'
alias ll1='tree --dirsfirst -ChFupDaL 1'
alias ll2='tree --dirsfirst -ChFupDaL 2'
alias ll3='tree --dirsfirst -ChFupDaL 3'

# wget + dpatch
wpatch() {
	PATCH_URL="$1"; shift
	echo "wget $PATCH_URL -O- | zless | cat | patch -p1 $@"
	wget $PATCH_URL -O- | zless | patch -p1 "$@"
}
# auto ssh-add key
alias ssh='if ! ssh-add -l >/dev/null 2>&1; then ssh-add; fi; ssh'

# make (overwriting) file operations interactive by default
alias cp="cp -i"
alias mv="nocorrect mv -i"

c() {
	local prev=$PWD
	[[ -d "$@" ]] && cd "$@" || j "$@"
	[[ $PWD != $prev ]] && ls
}
mdc() { mkdir "$@" && cd "$1" }

# verynice: wrap with ionice (if possible) and "nice -n19"
_verynice_ionice=
verynice() {
  if [[ -z $_verynice_ionice && -x ${commands[ionice]} ]]; then
    _verynice_ionice="ionice -c3" && $=_verynice_ionice true 2>/dev/null \
    || ( _verynice_ionice="ionice -c2 -n7" && $=_verynice_ionice true 2>/dev/null ) \
    || _verynice_ionice=
  fi
  nice -n 19 $=_verynice_ionice $@
}

# Mercurial
alias hgu="hg pull -u"
alias hgl="hg log -G | $PAGER" # -G via graphlog extension

# Quickly lookup entry in Wikipedia.
# Source: https://github.com/msanders/dotfiles/blob/master/.aliases
wiki() {
	if [[ $1 == "" ]]; then
		echo "usage: wiki [term]";
	else
		dig +short txt $1.wp.dg.cx;
	fi
}

screen() {
  local term=$TERM
  if [ "$TERM" = rxvt-unicode-256color ]; then
    term=rxvt-256color
    echo "Working around screen bug #30880, using TERM=$term.." # http://savannah.gnu.org/bugs/?30880
    sleep 2
  fi
  if [ -x /usr/bin/tput ] && [ $(/usr/bin/tput colors 2>/dev/null || echo 0) -eq 256 ]; then
    TERM=$term command screen -T screen-256color "$@"
  else
    TERM=$term command screen "$@"
  fi
}

alias idn='idn --quiet'
