# Query/use custom command for `git`.
zstyle -s ":vcs_info:git:*:-all-" "command" _git_cmd
: ${_git_cmd:=git}

# Aliases
alias g='git'
# To bypass git-so-fancy.
# alias gnp='git --no-pager'
alias git-no-fancy='git -c pager.diff="less" -c pager.log="less" -c pager.show="less"'
alias gnf='git -c pager.diff="less" -c pager.log="less" -c pager.show="less"'

alias ga='git add'
alias gap='git add --patch'
alias gae='git add --edit'

# Function for "git branch", handling the "list" case, by sorting it according
# to committerdate, and displaying it.
gb() {
  setopt localoptions rcexpandparam
  local refs limit=100
  if [[ -z $1 ]]; then
    refs=(refs/heads)
  elif [[ $# == 1 ]]; then
    if [[ $1 == '-r' ]]; then
      refs=(refs/remotes)
    elif [[ $1 == '-a' ]]; then
      refs=(refs/heads refs/remotes)
    elif [[ $1 == <-> ]]; then
      # Display last X branches only.
      refs=(refs/heads)
      limit=$1
    elif [[ $1 == '--no-merged' ]]; then
      # Pass options to git-branch, e.g. '--no-merged' and use resulting refs.
      refs=(refs/heads/${(@)$($_git_cmd branch $1)})
    fi
  fi

  if [[ -n $refs ]]; then
    local color_object=${(%):-'%F{yellow}'}
    local color_date=${(%):-'%F{cyan}'}
    local color_subject=${(%):-'%B%f'}
    local color_author=${(%):-'%F{blue}'}
    local color_current=${(%):-$(git config --get-color color.branch.current blue)}
    local color_local=${(%):-$(git config --get-color color.branch.local normal)}
    local color_remote=${(%):-$(git config --get-color color.branch.remote red)}
    local current=$(current_branch)
    local line
    typeset -a lines info_string
    info_string=(
      "%(refname:short)"
      "%(authorname)"
      "${color_date}%(committerdate:relative)${reset_color}"
      "${color_subject}%(subject)${reset_color}"
      "%(objectname:short)"
    )
    local my_name="$($_git_cmd config user.name)"
    local b
    for b in ${(f)"$($_git_cmd for-each-ref --sort=-committerdate $refs \
        --format="\0${(j:\0:)info_string}" --count=$limit)"}; do
      b=(${(s:\0:)b})
      line=""

      # Describe object name (and keep orig sha for comparison with prev_sha).
      b[6]=${b[5]}
      b[5]="${color_object}$($_git_cmd describe --contains --always $b[5])${reset_color}"

      # Decorate or remove author name.
      local author_name=$b[2]
      b=($b[1] $b[3,-1])
      if [[ $author_name != $my_name ]]; then
        b[3]="$b[3] (${color_author}$author_name${reset_color})"
      else
        # Include escape codes for zformat alignment.
        b[3]="$b[3] ${color_author}${reset_color}"
      fi

      lines+=("${b[1]}\0${(j-\0-)${(@)b[2,-1]}}")
    done

    # Use zformat recursively, which requires escaping ":" on the left side.
    typeset -a before escaped_lines format_lines
    local i left right split
    # Copy lines to format_lines with last column (orig sha) removed.
    for line in $lines; do
      split=(${(s:\0:)line})
      format_lines+=("${(j:\0:)split[1,-2]}")
    done
    local col=1

    local maxlen
    while true; do
      before=($format_lines)
      escaped_lines=()

      local linenum=1
      if (( COLUMNS > 100 )); then
        (( $col == 1 )) && maxlen=50 || maxlen=30
      else
        (( $col == 1 )) && maxlen=40 || maxlen=20
      fi
      for line in $format_lines; do
        split=(${(s:\0:)line})
        if (( ${#:-"$(remove_ansi_codes ${split[$col]})"} > $maxlen )); then
          split[$col]="__skipped_$(printf '.%.0s' {1..$((maxlen-10))})"
        fi
        # Escape left side.
        left=${${(j:\0:)split[1,$col]}//:/\\:}
        left=${left//\0/\\0}
        right=${(j:\0:)split[$((col+1)),-1]}
        escaped_lines+=("$left:$right")

        (( linenum++ ))
      done

      zformat -a format_lines "\0" $escaped_lines
      if (( ++col >= $#split )); then
        break
      fi
    done

    (( $#format_lines )) || return

    local orig_cols orig_col1 sha
    local cur_sha="$($_git_cmd rev-parse --verify -q --short HEAD)"
    local prev_sha="$($_git_cmd rev-parse --verify -q --short @{-1})"
    for i in {1..$#format_lines}; do
      line=$format_lines[$i]
      split=(${(s:\0:)line})
      for col in {1..$#split}; do
        if [[ $split[$col] == "__skipped_"* ]]; then
          split[$col]=${${(s:\0:)lines[$i]}[$col]}
        fi
      done

      # Prepend different colors.
      orig_cols=(${(s:\0:)lines[$i]})
      orig_col1=${orig_cols[1]}
      sha="${orig_cols[-1]}"
      if [[ $sha == $cur_sha ]]; then
        split[1]="* $split[1]"
      elif [[ $sha == $prev_sha ]]; then
        split[1]="- $split[1]"
      else
        split[1]="  $split[1]"
      fi

      if [[ $orig_col1 == $current ]]; then
        # split[1]="${(%):-%B}${split[1]}${(%):-%b}"
        split[1]="${color_current}$split[1]"
      elif [[ $orig_col1 == */* ]]; then
        split[1]="${color_remote}$split[1]"
      else
        split[1]="${color_local}$split[1]"
      fi

      # if [[ ${format_lines[$line]} != "skipped" ]]; then
      lines[$i]=${(j: :)split}
    done

    # Display it using "less", but only to cut at $COLUMNS.
    echo ${${(j:\n:)lines}} \
      | less --no-init --chop-long-lines --QUIT-AT-EOF
  else
    git branch "$@"
  fi
}
compdef -e 'words=(git branch "${(@)words[2,-1]}"); ((CURRENT++)); _normal' gb

alias gbr='hub browse'
# git branches, sorted by date (based on http://stackoverflow.com/a/22972547/15690).
gbd() {
    local reset_color=`tput sgr0`
    local subject_color=`tput setaf 4 ; tput bold`
    local author_color=`tput setaf 6`
    local target=refs/heads
    local branch_color=`git config --get-color color.branch.local blue`
    if [ "$1" = -r ]; then
        target=refs/remotes/origin
        branch_color=`git config --get-color color.branch.remote red`
    fi
    git for-each-ref --sort=committerdate $target \
        --format="%(committerdate:short) ${branch_color}%(refname:short)${reset_color} ${subject_color}%(subject)${reset_color} ${author_color}- %(authorname)${reset_color}" \
        | less --no-init --chop-long-lines --QUIT-AT-EOF
}
gbm() {
  gbmcleanup -l $*
}
alias gbnm='gb --no-merged'

alias gbsg='git bisect good'
alias gbsb='git bisect bad'
alias gbsr='git bisect reset'

# Delete or list merged branched.
gbmcleanup() {
  setopt localoptions errreturn
  local -a opts only
  zparseopts -D -a opts f q h i n l m v o+:=only
  local curb merged
  local -A no_diff
  local from_branches='^(master|develop)$'
  local keep_branches='^(master|develop|local)$'

  if (( $opts[(I)-h] )); then
    echo "Cleans merged branches."
    echo "$0 [-i] [-f] [-n] [-l] [-m] [-v] [-o branch]"
    echo " -l: list"
    echo " -n: dry run"
    echo " -i: interactive"
    echo " -f: force"
    echo " -m: test for empty merges"
    echo " -v: verbose"
    return
  fi
  local interactive=$opts[(I)-i]
  local force=$opts[(I)-f]
  local dry_run=$opts[(I)-n]
  local list=$opts[(I)-l]
  local test_merges=$opts[(I)-m]
  local verbose=$opts[(I)-v]
  only=(${only:#-o})
  local branch="$1"

  curb="$(current_branch)"
  if [[ -z $curb ]]; then
    echo "No current branch. Aborting."
    return 1
  fi

  if ! (( $list )) && ! (( $force )) && ! (( $dry_run )) \
      && ! [[ $curb =~ $from_branches ]] ; then
    echo "Current branch does not match '$from_branches'." 2>&1
    echo "Use -f to force." 2>&1
    return 1
  fi

  merged=($($_git_cmd branch --merged $branch | sed '/^*/d' | cut -b3- \
    | sed "/$keep_branches/d"))

  local b not_merged
  not_merged=(${(f)"$($_git_cmd branch --no-merged | cut -b3- | sed "/$keep_branches/d")"})
  if [[ -n $only ]]; then
    not_merged=(${not_merged:*only})
  fi

  local branch_color=`git config --get-color color.branch.local blue`
  local reset_color=`tput sgr0`

  if (( $#not_merged )); then
    if (( $test_merges )); then
      local diff out cmd rev_list merge_base
      local -A rev_diff
      for b in $not_merged; do
        echo -n '.'
        # Look for empty merges (no hunks with git-merge-tree).
        # Otherwise "merged" means that it could be merged without conflicts.
        merge_base=$($_git_cmd merge-base HEAD "$b")
        cmd=($_git_cmd merge-tree $merge_base HEAD "$b")
        out=("${(@f)$($cmd)}")
        if ! print -l $out | \grep -q '^@@'; then
          no_diff+=($b "empty merge")
          continue
        else
          # Check for cherry-picks, that cause a conflict with merge-tree, but
          # should be OK.
          rev_list=(${(f)"$($_git_cmd rev-list --abbrev-commit "$merge_base..HEAD")"})
          branch_diff=$($_git_cmd diff "$merge_base" $b)
          for i in $rev_list; do
            if [[ -z "${rev_diff[$i]}" ]]; then
              rev_diff[$i]="$(git diff "$i^" "$i")"
            fi
            if [[ "$rev_diff[$i]" == "$branch_diff" ]]; then
              no_diff+=($b "cherry-picked in $($_git_cmd name-rev $i)")
              continue
            fi
          done
        fi
        if (( $verbose )); then
          if (( $#only )); then
            echo "cmd: $cmd" >&2
            print -l $out >&2
          else
            echo "$out[1]: $branch_color$b$reset_color ($#out lines)" >&2
          fi
        fi
      done
      echo
    else
      echo "NOTE: Not testing $#not_merged non-merged branches, use -m." >&2
    fi
  fi

  if (( $list )); then
    if (( $#merged )); then
      echo ${(%):-"%BMerged branches:%b"} >&2
      for b in $merged; do
        echo "$branch_color$b$reset_color"
      done
    fi
    if (( $#no_diff )); then
      echo ${(%):-"%BBranches with empty merges:%b"} >&2
      for b in ${(k)no_diff}; do
        echo "$branch_color$b$reset_color: $no_diff[$b]"
      done
    fi
    return
  fi
  merged+=($no_diff)
  if ! (( $#merged )); then
    return
  fi

  local cmd
  cmd=(git branch -D)
  if (( $dry_run )); then
    cmd=(echo $cmd)
  fi

  if (( $interactive )); then
    echo "$#merged branches to process: " $merged

    for b in $merged; do
      view +'set ft=diff' =(echo "== $b =="; git show $b)
      printf "Delete? "
      read -q || { echo; continue }; echo
      $cmd $b
    done
  else
    $cmd $merged
  fi
}

alias gbl='git blame'

alias gc='git commit -v'
alias gca='git commit -v -a'
alias gcf='git commit --fixup'
alias gcs='git commit --squash'
gcl() {
  git clone $@ || return

  # Test if last arg is available as dir.
  local last=$@[$#]
  if [[ $# != 1 ]] && [[ -d $last ]]; then
    cd $last
  else
    # Handle automatic dir names: "user/repo" => "repo".
    local dir=${${last:t}%.git}
    if [[ -d $dir ]]; then
      cd $dir
    fi
  fi
}
compdef _git gcl=git-clone

# Helper: call a given command ($1) with (optional) files (popped from the
# end).  This allows for "gcm 'commit message' file1 file2", but also just
# "gcm message".
command_with_files() {
  local cmd=$1; shift
  # Pop existing files/dirs from the end of args.
  files=()
  while (( $# > 1 )) && [[ -e $@[$#] ]]; do
    files+=($@[$#])
    shift -p
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

gco() {
  # Safety net for accidental "gco ." (instead of "gco -").
  if (( ${@[(I).]} )); then
    echo "WARN: 'git checkout .' will remove local changes."
    echo -n "Continue? [y/N] "
    read -q || return 1
    echo
  fi
  git checkout "$@"
}
# Setup proper zstyle completion context for "git-checkout".
compdef -e 'words[1]=git-checkout; service=git-checkout; _git "$@"' gco

alias gcom='git checkout master'
alias gcoom='git checkout origin/master'
alias gcoum='git checkout upstream/master'

# Use `--no-track` to make `ggpush` not default to `origin`, when it
# should be my fork really.  Let `ggpush` / the first push setup the tracking
# branch/remote instead.
gcobo() {
  [[ -z $1 ]] && { echo "Branch name missing to create from origin/master."; return 1; }
  git checkout --no-track -b $1 origin/master
}
gcobu() {
  [[ -z $1 ]] && { echo "Branch name missing to create from upstream/master."; return 1; }
  git checkout --no-track -b $1 upstream/master
}

# Checkout a pull request (via refs on Github).
gf_upstream() {
  for i in upstream origin; do
    if $_git_cmd config "remote.$i.url" >/dev/null; then
      echo $i
      return
    fi
  done
  echo 'gf_upstream: no remote found!' >&2
  return 1
}
gfpr() {
  local remote
  remote=${2-$(gf_upstream)} || return
  git fetch -f $remote pull/$1/head:remotes/$remote/pr/$1
}
gcopr() {
  local pr=${1:t}
  local remote
  remote=${2-$(gf_upstream)} || return
  gfpr "$pr" "$remote" && git checkout remotes/$remote/pr/$pr
}

alias gcount='git shortlog -s --numbered --email'
alias gcp='git cherry-pick'

alias gd='git diff --submodule=short --patch-with-stat'
# without diff-so-fancy
alias gdnf='git-no-fancy diff --submodule=short --patch-with-stat'
alias gdc='git diff --cached --patch-with-stat'
alias gdf='gd $(git merge-base --fork-point master)'

# `git diff` against upstream.
alias gdu='gd @{u}..'
alias gdom='gd origin/master..'
alias gdum='gd upstream/master..'

gdv() { $_git_cmd diff -w "$@" | view - }
compdef _git gdv=git-diff
alias gdt='git difftool'
alias gdtc='git difftool --cached'
alias gdtd='git difftool --dir-diff --tool=bc'

alias gf='git fetch'
alias gfa='git fetch --all --prune'

alias gl='git log --abbrev-commit --decorate --submodule=log --pretty="format:%C(yellow)%h%C(red)%d%C(reset) %s %C(green)(%cr) %C(blue)<%an>"'
alias glg='gl --graph'
alias gls='gl --graph --stat'
alias glp='gls -p --pretty=fuller'
# '-m --first-parent' shows diff for first parent.
alias glpm='gl -p -m --first-parent'

# `git log` against upstream.
alias glu='git log --stat @{u}...'
alias glom='git log --stat origin/master..'
alias glum='git log --stat upstream/master..'

alias glsu='git ls-files -o --exclude-standard'

alias gm='git merge'
alias gmt='git mergetool --no-prompt'
gp() {
  # git-push: use "--force-with-lease" for "-f" (instead of "--force").
  local opts force_idx=$(( ${@[(I)-f]} ))
  opts=($@)
  if (( force_idx )); then
    opts[$force_idx]="--force-with-lease"
  fi
  git push $opts
}
compdef _git gp=git-push
alias gpl='git pull --ff-only'
alias gpoat='git push origin --all && git push origin --tags'
# Pull (ff-only) with auto-stashing (requires git 2.6+, 2015-09-28).
alias gup="git -c rebase.autoStash=true pull --rebase"

# Rebase
alias grbi='git rebase -i --autostash'
alias grbiom='grbi origin/master'
alias grbium='grbi upstream/master'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'

grh() {
  git reset "${@:-HEAD}"
}
compdef _git grh=git-reset

alias gr='git remote'
alias grv='git remote -v'

# Will cd into the top of the current repository
# or submodule. NOTE: see also `RR`.
alias grt='cd $($_git_cmd rev-parse --show-toplevel || echo ".")'

alias gsh='git show'
alias gsm='git submodule'
alias gsms='git submodule summary'
alias gsmst='git submodule status'
alias gss='git status -s'
alias gst='git status'

# git-stash.
alias gsts='git stash show --text -p --stat'
alias gsta='git stash'
alias gstas='git stash -k'
alias gstl='git stash list --format="%C(yellow)%gd: %C(reset)%gs %m%C(bold)%cr"'

# 'git stash pop', which warns when using it on a different branch.
gstp() {
  local log stash_ref
  if [[ "$1" = <-> ]] || [[ -z "$1" ]]; then
    stash_ref="stash@{${1:-0}}"
  else
    stash_ref="$1"
  fi
  log=$(git log -g --pretty="%s" $stash_ref -1) || {
    echo "Failed to display log for $stash_ref."
    return 1
  }
  local current_branch="$(current_branch)"
  if ! [[ $log =~ "^(WIP on|On) ${current_branch}" ]]; then
    echo "Warning: stash appears to be for another branch."
    echo "Current: ${current_branch}"
    echo "Log: $log"
    echo -n "Continue? "
    read -q || { echo; return }; echo
  fi
  git stash pop -q $stash_ref
  git status --untracked-files=no
}
compdef -e 'words=(git stash pop "${(@)words[2,-1]}"); ((CURRENT+=2)); _normal' gstp

# git-up and git-reup from ~/.dotfiles/usr/bin
compdef _git git-up=git-fetch
compdef _git git-reup=git-fetch
# "git submodule commit":
gsmc() {
  [ x$1 = x ] && { echo "Commit update to which submodule?"; return 1;}
  [ -d "$1" ] || { echo "Submodule $1 not found."; return 2;}
  summary=$($_git_cmd submodule summary "$1" 2>&1)
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

  $_git_cmd commit -m "Update submodule $1 ${${(ps: :)summary[1]}[3]}"$'\n\n'"${(F)summary}" "$1"
}
# "git submodule add":
gsma() {
  [ x$1 = x ] && { echo "Add which submodule?"; return 1;}
  [ x$2 = x ] && { echo "Where to add submodule?"; return 2;}
  local sm=$1; shift
  local smpath=$1; shift
  $_git_cmd diff --cached --exit-code > /dev/null || { echo "Index is not clean."; return 1 ; }
  # test for clean .gitmodules
  local -h gitroot=./$($_git_cmd rev-parse --show-cdup)
  if [[ -f $gitroot/.gitmodules ]]; then
    $_git_cmd diff --exit-code $gitroot/.gitmodules > /dev/null || { echo ".gitmodules is not clean."; return 2 ; }
  fi
  echo git submodule add "$@" "$sm" "$smpath"
  git submodule add "$@" "$sm" "$smpath" && \
  summary=$($_git_cmd submodule summary "$smpath") && \
  summary=( ${(f)summary} ) && \
  $_git_cmd commit -m "Add submodule $smpath @${${${(ps: :)summary[1]}[3]}/*.../}"$'\n\n'"${(F)summary}" "$smpath" $gitroot/.gitmodules && \
  $_git_cmd submodule update --init "$smpath"
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
  setopt localoptions errreturn
  [ x$1 = x ] && { echo "Remove which submodule?"; return 1;}
  [ -d "$1" ] || { echo "Submodule $1 not found."; return 2;}
  [ -f .gitmodules ] || { echo ".gitmodules not found."; return 3;}
  $_git_cmd diff --cached --exit-code > /dev/null || { echo "Index is not clean."; return 1 ; }
  # test for clean .gitmodules
  $_git_cmd diff --exit-code .gitmodules > /dev/null || { echo ".gitmodules is not clean."; return 2 ; }
  if [[ -f Makefile ]]; then
    $_git_cmd diff --exit-code Makefile > /dev/null || { echo "Makefile is not clean."; return 2 ; }
  fi

  $_git_cmd rm --cached $1

  # Manually remove submodule sections with older Git (pre 1.8.5 probably).
  # Not necessary at all, _after_ `rm --cached`?!
  # if $_git_cmd config -f .git/config --get submodule.$1.url > /dev/null ; then
  #   # remove submodule entry from .gitmodules and .git/config (after init/sync)
  #   $_git_cmd config -f .git/config --remove-section submodule.$1
  #   # tempfile=$(tempfile)
  #   # awk "/^\[submodule \"${1//\//\\/}\"\]/{g=1;next} /^\[/ {g=0} !g" .gitmodules >> $tempfile
  #   # mv $tempfile .gitmodules
  # fi
  $_git_cmd config -f .gitmodules --remove-section submodule.$1
  $_git_cmd add .gitmodules

  if [[ -f Makefile ]]; then
    # Add the module to the `migrate` task in the Makefile and increase its name:
    grep -q "rm_bundles=.*$1" Makefile || sed -i "s:	rm_bundles=\"[^\"]*:\0 $1:" Makefile
    i=$(( $(grep '^.stamps/submodules_rm' Makefile | cut -f3 -d. | cut -f1 -d:) + 1 ))
    sed -i "s~\(.stamps/submodules_rm\).[0-9]\+~\1.$i~" Makefile
    $_git_cmd add Makefile
  fi
  echo "NOTE: changes staged, not committed."
  echo "You might want to 'rm $1' now or run the migrate task."
}

gswitch() {
  [[ -z $1 ]] && { echo "Change to which branch?"; return 1 }
  local output="$($_git_cmd checkout $1 2>&1)"
  echo $output
  if [[ $output == "error: Your local changes"* ]]; then
    $_git_cmd stash save \
      && $_git_cmd checkout $1 \
      && $_git_cmd stash pop
  fi
}
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
    if [[ $i == -f ]]; then  # use --force-with-lease for -f.
      using_force=1
      i=--force-with-lease
    fi
    [[ $i == --force ]] && using_force=1
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
  ggpush "$@" && hub browse
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
