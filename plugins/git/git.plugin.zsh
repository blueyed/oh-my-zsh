# Query/use custom command for `git`.
zstyle -s ":vcs_info:git:*:-all-" "command" _git_cmd
: ${_git_cmd:=git}

# Aliases
alias g='git'
alias ga='git add'
alias gap='git add --patch'
alias gae='git add --edit'
alias gb='git branch'
alias gba='git branch -a'
alias gbnm='git branch --no-merged'
alias gbm='git branch --merged'
alias gbl='git blame'
alias gc='git commit -v'
alias gca='git commit -v -a'
gcl() {
  set -x
  git clone --recursive $@
  if [[ $# == 1 ]]; then
    cd ${1:t}
  fi
}
compdef _git gcl=git-clone

# Helper: call a given command with (optional) files as first args at the end.
command_with_files() {
  local cmd=$1; shift
  # Shift existing files/dirs from the beginning of args.
  files=()
  while (( $# > 0 )) && [[ -e $1 ]]; do
    files+=($1)
    shift
  done
  $=cmd "$*" $files
}

# Commit with message: no glob expansion and error on non-match.
# gcm() { git commit -m "${(V)*}" }
alias gcm='noglob _nomatch command_with_files "git commit -m"'
# Amend directly (with message): no glob expansion and error on non-match.
# gcma() { git commit --amend -m "${(V)*}" }
# gcma() { git commit --amend -m "$*" }
alias gcma='noglob _nomatch command_with_files "git commit --amend -m"'
alias gco='git checkout'
alias gcom='git checkout master'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'

alias gd='git diff --submodule'
alias gdc='git diff --cached'
# `git diff` against upstream (usually origin/master)
gdo() {
  _git_against_upstream diff "$@"
}
compdef _git gdo=git-diff
# `git log` against upstream (usually origin/master)
glo() {
  local opt
  [ x$1 = x ] && opt='--stat' || opt="$@"
  _git_against_upstream log "$opt"
}
compdef _git glo=git-log
_git_against_upstream() {
  local cmd
  [ x$1 = x ] && { echo "Missing command."; return 1; }
  cmd=(git $@ '@{upstream}..HEAD')
  echo $cmd
  $cmd
  if [[ $? == 128 ]]; then
    echo "Branch list:"
    git show-branch --list
  fi
}
gdv() { git diff -w "$@" | view - }
compdef _git gdv=git-diff
alias gdt='git difftool'
alias gdtc='git difftool --cached'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gl='git l'
# git log with patches.
alias glp='gl -p'
# '-m --first-parent' shows diff for first parent.
alias glpm='gl -p -m --first-parent'
alias glg='git log --stat --max-count=5'
alias glgg='git log --graph --max-count=5'
alias gls='git ls-files'
alias glsu='git ls-files -o --exclude-standard'
alias gm='git merge'
alias gmt='git mergetool --no-prompt'
alias gp='git push'
alias gpl='git pull --ff-only --verbose'
alias gpll='git pull'
alias gpoat='git push origin --all && git push origin --tags'
alias gr='git remote'

# Rebase
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'

alias grh='git reset HEAD'
alias grv='git remote -v'

# Will cd into the top of the current repository
# or submodule. NOTE: see also `RR`.
alias grt='cd $(git rev-parse --show-toplevel || echo ".")'

alias gsh='git show'
alias gsm='git submodule'
alias gsms='git submodule summary'
alias gsmst='git submodule status'
alias gss='git status -s'
alias gst='git status'
alias gssp='git stash show -p'

# NEW
alias gsts='git stash show --text'
alias gsta='git stash'
alias gstp='git stash pop'
alias gstd='git stash drop'

# git-up and git-reup from ~/.dotfiles/usr/bin
compdef _git git-up=git-fetch
compdef _git git-reup=git-fetch
# "git submodule commit":
gsmc() {
  [ x$1 = x ] && { echo "Commit update to which submodule?"; return 1;}
  [ -d "$1" ] || { echo "Submodule $1 not found."; return 2;}
  summary=$(git submodule summary "$1" 2>&1)
  if [[ $? != 0 ]]; then
    echo "Error with 'git submodule summary $1':\n$summary"; return 3
  fi
  if [[ $summary == "" ]] ; then
    echo "Submodule $1 not changed."; return 4
  fi
  if [[ $summary == fatal:* ]] ; then
    echo $summary ; return 5
  fi
  summary=( ${(f)summary} )

  # TODO: check that commits are pushed?!
  # relevant?! echo $summary | grep -o "Warn: $1 doesn't contain commit" && return 3

  git commit -m "Update submodule $1 ${${(ps: :)summary[1]}[3]}"$'\n\n'"${(F)summary}" "$1"
}
# "git submodule add":
gsma() {
  [ x$1 = x ] && { echo "Add which submodule?"; return 1;}
  [ x$2 = x ] && { echo "Where to add submodule?"; return 2;}
  local sm=$1; shift
  local smpath=$1; shift
  git diff --cached --exit-code > /dev/null || { echo "Index is not clean."; return 1 ; }
  # test for clean .gitmodules
  local -h gitroot=./$(git rev-parse --show-cdup)
  if [[ -f $gitroot/.gitmodules ]]; then
    git diff --exit-code $gitroot/.gitmodules > /dev/null || { echo ".gitmodules is not clean."; return 2 ; }
  fi
  echo git submodule add "$@" "$sm" "$smpath"
  git submodule add "$@" "$sm" "$smpath" && \
  summary=$(git submodule summary "$smpath") && \
  summary=( ${(f)summary} ) && \
  git commit -m "Add submodule $smpath @${${${(ps: :)summary[1]}[3]}/*.../}"$'\n\n'"${(F)summary}" "$smpath" $gitroot/.gitmodules && \
  git submodule update --init --recursive "$smpath"
}
# `gsma` for ~df/vim/bundles:
# Use basename from $1 without typical prefixes (vim-) and suffix (.git, .vim
# etc) for bundle name.
gsmav() {
  [ x$1 = x ] && { echo "Add which submodule?"; return 1;}
  local sm=$1; shift
  (
    cd ~df
    cmd="gsma $sm vim/bundle/${${${sm##*/}%(.|_|-)(git|vim|Vim)}#vim-} $@"
    echo "cmd: $cmd"
    echo "[press enter]"
    read -n
    $=cmd
  )
}
gsmrm() {
  # Remove a git submodule
  [ x$1 = x ] && { echo "Remove which submodule?"; return 1;}
  [ -d "$1" ] || { echo "Submodule $1 not found."; return 2;}
  [ -f .gitmodules ] || { echo ".gitmodules not found."; return 3;}
  git diff --cached --exit-code > /dev/null || { echo "Index is not clean."; return 1 ; }
  # test for clean .gitmodules
  git diff --exit-code .gitmodules > /dev/null || { echo ".gitmodules is not clean."; return 2 ; }
  if [[ -f Makefile ]]; then
    git diff --exit-code Makefile > /dev/null || { echo "Makefile is not clean."; return 2 ; }
  fi

  git rm --cached $1

  # Manually remove submodule sections with older Git (pre 1.8.5 probably).
  # Not necessary at all, _after_ `rm --cached`?!
  # if git config -f .git/config --get submodule.$1.url > /dev/null ; then
  #   # remove submodule entry from .gitmodules and .git/config (after init/sync)
  #   git config -f .git/config --remove-section submodule.$1
  #   # tempfile=$(tempfile)
  #   # awk "/^\[submodule \"${1//\//\\/}\"\]/{g=1;next} /^\[/ {g=0} !g" .gitmodules >> $tempfile
  #   # mv $tempfile .gitmodules
  # fi
  git config -f .gitmodules --remove-section submodule.$1
  git add .gitmodules

  if [[ -f Makefile ]]; then
    # Add the module to the `migrate` task in the Makefile and increase its name:
    grep -q "rm_bundles=.*$1" Makefile || sed -i "s:	rm_bundles=\"[^\"]*:\0 $1:" Makefile
    i=$(( $(grep '^.stamps/submodules_rm' Makefile | cut -f3 -d. | cut -f1 -d:) + 1 ))
    sed -i "s~\(.stamps/submodules_rm\).[0-9]\+~\1.$i~" Makefile
    git add Makefile
  fi
  echo "NOTE: changes staged, not committed."
  echo "You might want to 'rm $1' now or run the migrate task."
}
gswitch() {
  # TODO: `set -e` for functions
  [ x$1 = x ] && { echo "Change to which branch? (- for \$git_previous_branch ($git_previous_branch))"; return 1;}
  if [[ $1 == - ]]; then
    [ x$git_previous_branch = x ] && { echo "No previous branch."; return 2;}
    1=$git_previous_branch
  fi
  local cb=$(current_branch)
  if ! git checkout $1; then
    git stash save "Automatic stash from gswitch from: $cb"
    git checkout $1
    git stash pop
  fi
  git_previous_branch=$cb
}
# compdef _git gswitch=_git_commits  # calls __git_commits
compdef _git gswitch=git-checkout

alias gg='git gui citool'
alias gga='git gui citool --amend'
alias gk='gitk --all --branches'

# Git and svn mix
alias git-svn-dcommit-push='git svn dcommit && git push github master:svntrunk'
compdef git-svn-dcommit-push=git
alias gsvnup='git svn fetch && git stash && git svn rebase && git stash pop'

alias gsr='git svn rebase'
alias gsd='git svn dcommit'

# Will return the current branch name
# Usage example: git pull origin $(current_branch)
# Using '--quiet' with 'symbolic-ref' will not cause a fatal error (128) if
# it's not a symbolic ref, but in a Git repo.
function current_branch() {
  local ref
  ref=$($_git_cmd symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$($_git_cmd rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}

function current_repository() {
  if ! $_git_cmd rev-parse --is-inside-work-tree &> /dev/null; then
    return
  fi
  echo $($_git_cmd remote -v | cut -d':' -f 2)
}

# these aliases take advantage of the previous function
alias ggpull='git pull origin $(current_branch)'
compdef -e 'words[1]=(git pull origin); service=git; (( CURRENT+=2 )); _git' ggpull

ggpush() {
  local -h remote branch
  local -ha args git_opts

  # Get args (skipping options).
  local using_force=0
  for i; do
    [[ $i == -f || $i == --force ]] && using_force=1
    [[ $i == -* ]] && git_opts+=($i) || args+=($i)
    [[ $i == -h ]] && { echo "Usage: ggpush [--options...] [remote (Default: tracking branch / github.user)] [branch (Default: current)]"; return; }
  done

  remote=${args[1]}
  branch=${args[2]-$(current_branch)}
  # XXX: may resolve to "origin/develop" for new local branches..
  cfg_remote=${$($_git_cmd rev-parse --verify $branch@{upstream} \
        --symbolic-full-name 2>/dev/null)/refs\/remotes\/}
  cfg_remote=${cfg_remote%%/*}

  if [[ -z $remote ]]; then
    if [[ -z $cfg_remote ]]; then
      remote=$($_git_cmd config ggpush.default-remote)
      if ! [[ -z $remote ]]; then
        echo "Using ggpush.default-remote: $remote"
      fi
    fi
    if [[ -z $remote ]]; then
      remote=$($_git_cmd config github.user)
      echo "Using remote for github.user: $remote"
      if ! [[ -z $remote ]]; then
        # Verify remote from github.user:
        if ! $_git_cmd ls-remote --exit-code $remote &> /dev/null; then
          echo "NOTE: remote for github.user does not exist ($remote). Forking.."
          hub fork
        fi
      fi
      if [[ -z $remote ]]; then
        echo "ERR: cannot determine remote."
        return 1
      fi
      echo "NOTE: using remote from github.user: $remote"
    fi

    # Ask for confirmation with '-f' and autodetected remote.
    if [[ $using_force == 1 ]]; then
      echo "WARN: using '-f' without explicit remote."
      echo -n "Do you want to continue with detected $remote:$branch? [y/N] "
      read -q || return 1
      echo
    fi

  elif [[ -z $cfg_remote ]]; then
    # No remote given, and nothing configured: use `-u`.
    echo "NOTE: Using '-u' to set upstream."
    if (( ${git_opts[(i)-u]} > ${#git_opts} )); then
      git_opts+=(-u)
    fi
  fi

  echo "Pushing to $remote:$branch.."
  [[ -z $branch ]] && { echo "No current branch (given or according to 'current_branch').\nAre you maybe in a rebase, or not in a Git repo?"; return 1; }

  # TODO: git push ${1-@{u}} $branch
  local -a cmd
  cmd=(git push $git_opts $remote $branch)
  echo $cmd
  $=cmd
}
compdef _git ggpush=git-push

ggpushb() {
  ggpush "$@" && git browse
}
compdef _git ggpushb=git-push

# Setup wrapper for git's editor. It will use just core.editor for other
# files (e.g. patch editing in `git add -p`).
export GIT_EDITOR=vim-for-git

# these alias ignore changes to file
alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'
# list temporarily ignored files
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
