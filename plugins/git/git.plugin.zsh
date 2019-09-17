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

# Optimized version of remove_ansi_codes (using Zsh features, no subshell).
get_remove_ansi_codes() {
  ret=${1//\[([0-9][0-9](;[0-9][0-9])#)#[mK]/}
}

# Function for "git branch", handling the "list" case, by sorting it according
# to committerdate, and displaying it.
gb() {
  setopt localoptions rcexpandparam
  local refs limit=100

  if [[ $# == 0 ]]; then
    refs=(refs/heads)
  else
    # Parse -r and -a for special handling.
    local parsed_opts
    zparseopts -D -E -a parsed_opts r a

    # Parse all other args/opts.
    typeset -a opts args
    for i do
      if [[ ${i[1]} == '-' ]]; then
        opts+=($i)
      else
        args+=($i)
      fi
    done

    if (( $#parsed_opts )); then
      if (( $parsed_opts[(I)-r] )); then
        refs=(refs/remotes)
      elif (( $parsed_opts[(I)-a] )); then
        refs=(refs/heads refs/remotes)
      fi
    fi

    if (( $opts[(I)(--no-merged|--merged)] )); then
      # Pass options to git-branch, e.g. '--no-merged' and use resulting refs.
      refs=(refs/heads/${(@)$($_git_cmd branch --list $opts | sed -E 's/^[* ] //')})
    fi

    # If there is only one number arg, and no pass-through option (e.g. "-D"),
    # then use that as a limit.
    if ! (( $#opts )) && (( $#args == 1 )); then
      if [[ $args[1] == <-> ]]; then
        # Display last X branches only.
        if [[ -z $refs ]]; then
          refs=(refs/heads)
        fi
        limit=$args[1]
      fi
    fi
  fi

  if [[ -z $refs ]]; then
    git branch "$@"
  else
    # XXX: there's a problem with ANSI escape codes, which get considered by
    # zformat, although invisible.

    local color_upstream=${(%):-'%F{blue}'}
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
      "%(refname:short) ${color_upstream}%(upstream:trackshort)${reset_color}"
      "%(authorname)"
      "${color_date}%(committerdate:format:%Y-%m-%d %H:%M)${reset_color}"
      "${color_subject}%(subject)${reset_color}"
      "%(objectname:short)"
    )
    local my_name="$($_git_cmd config user.name)"
    local b
    local -a branch_info branch_refs branches_describe
    branch_info=(${(f)"$($_git_cmd for-each-ref --sort=-committerdate $refs \
      --format="\0${(j:\0:)info_string}" --count=$limit)"})
    for b in $branch_info; do
      b=(${(s:\0:)b})
      branch_refs+=($b[5])
    done

    # Do a single call to git-describe.
    branches_describe=(${(f)"$($_git_cmd describe --contains --always $branch_refs)"})

    local author_name
    for idx in {1..$#branch_info}; do
      b=(${(s:\0:)branch_info[idx]})

      # Describe object name (and keep orig sha for comparison with prev_sha).
      b[6]=${b[5]}
      b[5]="${color_object}${branches_describe[$idx]}${reset_color}"

      # Decorate or remove author name.
      author_name=$b[2]
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

    local col maxlen ret
    # Format first two columns (branch and subject) using zformat.
    for col in {1..2}; do
      before=($format_lines)
      escaped_lines=()

      if (( COLUMNS > 100 )); then
        (( $col == 1 )) && maxlen=50 || maxlen=30
      else
        (( $col == 1 )) && maxlen=40 || maxlen=20
      fi
      for line in $format_lines; do
        split=(${(s:\0:)line})
        get_remove_ansi_codes ${split[$col]}
        if (( $#ret > $maxlen )); then
          split[$col]="__skipped_$(printf '.%.0s' {1..$((maxlen-10))})"
        fi
        # Escape left side.
        left=${${(j:\0:)split[1,$col]}//:/\\:}
        left=${left//\0/\\0}
        right=${(j:\0:)split[$((col+1)),-1]}
        escaped_lines+=("$left:$right")
      done

      zformat -a format_lines "\0" $escaped_lines
    done

    (( $#format_lines )) || return

    local orig_cols refname_short sha
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
      refname_short=${${(s: :)orig_cols[1]}[1]}
      sha="${orig_cols[-1]}"
      if [[ $sha == $cur_sha ]]; then
        split[1]="* $split[1]"
      elif [[ $sha == $prev_sha ]]; then
        split[1]="- $split[1]"
      else
        split[1]="  $split[1]"
      fi

      if [[ $refname_short == $current ]]; then
        # split[1]="${(%):-%B}${split[1]}${(%):-%b}"
        split[1]="${color_current}$split[1]"
      elif [[ $refname_short == */* ]]; then
        split[1]="${color_remote}$split[1]"
      else
        split[1]="${color_local}$split[1]"
      fi

      lines[$i]=${(j: :)split}
    done

    # Display it using "less", but only to cut at $COLUMNS.
    printf '%s\n' $lines | less --no-init --chop-long-lines --QUIT-AT-EOF
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
  zparseopts -D -a opts f q h i n l m v o+:=only k+:=keep
  local curb merged
  local -A no_diff
  local from_branches='^(master|develop)$'
  local keep_branches='^(master|develop|local)$'

  if (( $opts[(I)-h] )); then
    echo "Cleans merged branches."
    echo "$0 [-i] [-f] [-n] [-l] [-m] [-v] [-o branch]… [-k branch]…"
    echo " -l: list"
    echo " -n: dry run"
    echo " -i: interactive (show diff for each branch, asking for confirmation)"
    echo " -f: force"
    echo " -m: test for empty merges"
    echo " -o: only test specified branches"
    echo " -k: keep specified branches"
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
  keep=(${keep:#-k})
  local branch="$1"

  if [[ -z "$branch" ]]; then
    branch="$(current_branch)"
    if [[ -z $branch ]]; then
      echo "No current branch. Aborting."
      return 1
    fi
  fi

  if ! (( $list )) && ! (( $force )) && ! (( $dry_run )) \
      && ! [[ $branch =~ $from_branches ]] ; then
    echo "Current branch does not match '$from_branches'." 2>&1
    echo "Use -f to force." 2>&1
    return 1
  fi

  local sed_branch="${branch//\//\\/}"
  local sed_keep_branches="${keep_branches//\//\\/}"

  merged=($($_git_cmd branch --merged $branch | sed -E "/^[* ] $sed_branch\$/d" \
    | cut -b3- | sed -E "/$sed_keep_branches/d"))
  if [[ -n $keep ]]; then
    merged=(${merged:|keep})
  fi

  local b not_merged
  not_merged=(${(f)"$($_git_cmd branch --no-merged | cut -b3- \
    | sed -E "/$sed_keep_branches/d")"})
  if [[ -n $only ]]; then
    not_merged=(${not_merged:*only})
  fi

  local branch_color=`git config --get-color color.branch.local blue`
  local reset_color=`tput sgr0`
  local cmd

  if (( $#not_merged )); then
    if (( $test_merges )); then
      local diff lines out rev_list merge_base
      local -A rev_diff
      local display_progress=$(($#not_merged > 20))
      local -F 2 start duration
      local last_b
      local max_revs=1000
      local -A skipped_max=()
      for b in $not_merged; do
        if [[ -n "$last_b" ]]; then
          duration=$(( ($(print -P '%D{%s%.}') - start) / 1000 ))
          if (( duration > 1.0 )); then
            echo "slow: $last_b (${duration}s)"
          fi
        fi
        start=$(print -P '%D{%s%.}')
        last_b=$b
        (( display_progress )) && echo -n '.' >&2
        # Look for empty merges (no hunks with git-merge-tree).
        # Otherwise "merged" means that it could be merged without conflicts.
        merge_base=$($_git_cmd merge-base HEAD "$b")
        cmd=($_git_cmd merge-tree $merge_base HEAD "$b")
        out="$($cmd)"
        if ! [[ "$out" == *$'\n@@'* ]]; then
          no_diff+=($b "empty merge")
          continue
        else
          lines=("${(f)out}")
          # Check for cherry-picks, that cause a conflict with merge-tree, but
          # should be OK.
          rev_list=(${(f)"$($_git_cmd rev-list --abbrev-commit "$merge_base..HEAD")"})
          branch_diff=$($_git_cmd diff "$merge_base" $b --)
          local c=0
          for i in $rev_list; do
            if (( ++c == max_revs )); then
              skipped_max+=($b $#rev_list)
              break
            fi
            if [[ -z "${rev_diff[$i]}" ]]; then
              # Might cause "fatal: bad revision '6b135c83^'" (pytest repo)
              if ! rev_diff[$i]="$(git diff "$i^" "$i" -- 2>&1)"; then
                echo "error: $b: $rev_diff[$i] (merge-base: $merge_base, $c/$#rev_list)"
                continue
              fi
            fi
            if [[ "$rev_diff[$i]" == "$branch_diff" ]]; then
              no_diff+=($b "cherry-picked in $($_git_cmd name-rev $i)")
              break
            fi
          done
        fi
        if (( $verbose )); then
          if (( $#only )); then
            echo "cmd: $cmd" >&2
            print -l $lines >&2
          else
            echo "$lines[1]: $branch_color$b$reset_color ($#lines lines)" >&2
          fi
        fi
      done
      (( display_progress )) && echo
      if (( $#skipped_max )); then
        local info=()
        for k in ${(k)skipped_max}; do
          info+=("$k ($skipped_max[$k])")
        done
        echo "NOTE: skipped $#skipped_max branches due to max ($max_revs) reached: ${(j:, :)info}."
      fi
    else
      echo "NOTE: Not testing $#not_merged non-merged branches, use -m." >&2
    fi
  fi

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
  if (( $list )); then
    return
  fi
  merged+=(${(k)no_diff})
  if ! (( $#merged )); then
    return
  fi

  if ! (( $interactive )); then
    printf "Delete? (y/N) "
    read -q || { echo; return }; echo
  fi

  cmd=(git branch -D)
  if (( $dry_run )); then
    cmd=(echo $cmd)
  fi

  if (( $interactive )); then
    echo "$#merged branches to process: $merged"

    for b in $merged; do
      view '+set ft=diff' =(echo "== $b =="; git show $b)
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
alias gC='git commit'  # For large diffs.
alias gca='git commit -v -a'

# Helper to setup completion for functions.
# "complete_function gcf git commit --fixup" will setup completion for
# "gcf" => "git commit --fixup".
complete_function() {
  local f=$1; shift
  compdef -e "words[1]=( ${${(qq)@}} ); (( CURRENT += $# - 1 )); _normal" $f
}

gcf() {
  typeset -a opts
  while [[ $1 == -* ]]; do opts+=($1); shift; done
  gc $opts --fixup "${@:-HEAD}"
}
complete_function gcf git commit --fixup

gcs() {
  typeset -a opts
  while [[ $1 == -* ]]; do opts+=($1); shift; done
  gc $opts --squash "${@:-HEAD}"
}
complete_function gcs git commit --squash

gcl() {
  hub clone $@ || return

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
_git_command_with_message_and_files() {
  local cmd files
  cmd=($=1); shift
  files=()
  if [[ $1 == *" "* ]]; then
    # Pop existing files/dirs from the end of args (but only if the message is
    # quoted and contains space.
    # This is meant to skip "Makefile" with "gcm Improve Makefile".
    while (( $# > 1 )) && [[ -e $@[$#] ]]; do
      files+=($@[$#])
      shift -p
    done
  fi
  cmd+=(-m "$*")
  $cmd $files
}
_git_command_with_message() {
  local cmd msg
  cmd=($=1); shift

  # Handle any args before the message.
  while [[ $1 == -* ]] && [[ $1 != -- ]]; do
    cmd+=($1); shift
  done

  if (( $# )); then
    cmd+=(-m "$*")
  else
    cmd+=(--reuse-message=HEAD)
  fi
  $cmd
}

# Commit with message: no glob expansion and error on non-match.
alias gcm='noglob _git_command_with_message_and_files "git commit"'
# Amend directly (with message): no glob expansion and error on non-match.
gcma() {
  _git_command_with_message "git commit --amend" "$@"
}
alias gcma='noglob gcma'
complete_function gcma git commit --amend

# Commit index after creating a branch based on the msg's first line.
gcobucm() {
  # Only use first line of arguments
  setopt localoptions errreturn
  if git diff --cached --quiet --exit-code; then
    echo "error: nothing to commit in the index"; return 1
  fi
  local msg="$@"
  local lines=(${(@f)msg})
  local firstline=$lines[1]
  local branch="${${${${${${firstline:gs/: /-}:gs/ /_}:gs~/~-}:gs/:/-/}:gs/*/star/}:l}"
  gcobu $branch || return
  gcm $msg
}

gco() {
  # Safety net for accidental "gco ." (instead of "gco -").
  # Could also kick in in case of dir names, when a branch was meant?!
  if (( ${@[(I).]} )) && ! (( ${@[(I)-p]} )); then
    echo "WARN: 'git checkout .' will remove local changes."
    echo -n "Continue? [y/N] "
    read -q || { echo; return 1 }; echo
    echo
  fi
  git checkout "$@"
}
# Setup proper zstyle completion context for "git-checkout".
compdef -e 'words=(git checkout "${(@)words[2,-1]}"); ((CURRENT++)); _normal' gco

# Special completion of "aliases" (only branches).
# Use a function instead of alias (for nocompletealiases).
gcob() { git checkout "$@" }
compdef -e 'f=__git_recent_branches; (( $+functions[$f] )) || _git; $f' gcob
gcobn() { git checkout "$@" }
compdef -e 'f=__git_branch_names; (( $+functions[$f] )) || _git; $f' gcobn

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
gcobum() {
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
alias gF='git fetch --prune'
alias gfa='git fetch --all'
alias gFa='git fetch --all --prune'
alias gfo='git fetch origin'

alias gl='git log --abbrev-commit --decorate --submodule=log --pretty="format:%C(yellow)%h%C(red)%d%C(reset) %s %C(green)(%cr) %C(blue)<%an>"'
alias glg='gl --graph'
alias gls='gl --graph --stat'
alias glp='gls -p --pretty=fuller'
alias glpg='glp -G'
# '-m --first-parent' shows diff for first parent.
alias glpm='gl -p --pretty=fuller -m --first-parent'

# `git log` against upstream.
alias glu='git log --stat @{u}...'
alias glom='git log --stat origin/master..'
alias glum='git log --stat upstream/master..'

alias glsu='git ls-files -o --exclude-standard'

alias gm='git merge'
alias gmt='git mergetool --no-prompt'
gp() {
  # git-push
  #  - use "--force-with-lease" for "-f" (instead of "--force")
  #  - handle "-c" options (they need to be passed before "push")
  local opt
  local -a git_opts push_opts
  while (( ${#@} )); do
    opt=$1
    shift
    if [[ "$opt" == '-c' ]]; then
      git_opts=(-c $1)
      shift
    elif [[ "$opt" == '-f' ]]; then
      push_opts+=('--force-with-lease')
    else
      push_opts+=($opt)
    fi
  done
  git $git_opts push $push_opts
}
compdef _git gp=git-push
alias gpl='git pull --ff-only'
alias gpoat='git push origin --all && git push origin --tags'
# Pull (ff-only) with auto-stashing (requires git 2.6+, 2015-09-28).
alias gup="git -c rebase.autoStash=true pull --rebase"

# Rebase
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbom='git rebase origin/master'
alias grbu='git rebase $(git_upstream_master)'
# Interactive rebase
alias grbi='git rebase -i --autostash'
alias grbiom='grbi origin/master'
alias grbiu='grbi $(git_upstream_master)'
alias grbimb='grbi $(git merge-base --fork-point master)'

grh() {
  git reset "${@:-HEAD}"
}
compdef _git grh=git-reset

alias gr='git remote'
alias grv='git remote -v'

# Will cd into the top of the current repository
# or submodule. NOTE: see also `RR`.
alias grt='cd $($_git_cmd rev-parse --show-toplevel || echo ".")'

alias gsh='git show --stat -p'
alias gsm='git submodule'
alias gsms='git submodule summary'
alias gsmst='git submodule status'
alias gss='git --no-pager status -s'
alias gst='git --no-pager status --untracked-files=no'
alias gstu='git --no-pager status --untracked-files=normal'

# git-stash.
gsts() {
  if [[ -n "$1" ]]; then
    [[ "$1" = <-> ]] && skip=$1 || skip=${${1#stash@\{}%\}}
  else
    skip=0
  fi
  # Use "list" to get the stash subject, date etc.
  $_git_cmd stash list --text -p --stat -1 --skip=$skip --format=short
}
compdef -e 'words=(git stash show "${(@)words[2,-1]}"); ((CURRENT+=2)); _normal' gsts

_update_git_ctags() {
  ret=${1:-$?}
  if [[ "$ret" = 0 ]]; then
    local ctags_hook="$($_git_cmd rev-parse --git-path hooks/ctags)"
    if [[ -x "$ctags_hook" ]]; then
      echo "Updating ctags.."
      $ctags_hook
    fi
  fi
  return "$ret"
}
gsta() {
  $_git_cmd stash "$@"
  local ret=$?
  if [[ -z "$1" || "$1" == 'pop' || "$1" == 'apply' ]]; then
    _update_git_ctags $ret
  fi
  return $ret
}
complete_function gsta git stash
alias gstl='git stash list --format="%C(yellow)%gd: %C(reset)%gs %m%C(bold)%cr"'

# 'git stash pop', which warns when using it on a different branch/commit.
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
  local stash_branch="${${log##(WIP on|On) }%%:*}"
  if [[ "$stash_branch" == '(no branch)' ]]; then
    # Get commit from log message ("WIP on (no branch): c48d405 Change …")
    stash_branch="${${log##*: }%% *}"
  fi
  if [[ "$current_branch" != "$stash_branch" ]]; then
    echo "Warning: stash appears to be for another branch."
    echo "Current: $current_branch, stash: $stash_branch"
    echo "Log: $log"
    echo -n "Continue? (y/N) "
    read -q || { echo; return }; echo
  fi
  output="$($_git_cmd stash pop --index $stash_ref 2>&1)"
  local ret=$?
  if (( ret == 0 )); then
    # Simulate -q on success, but display the "Droppped" line/ref.
    # hash="$($_git_cmd show-ref --abbrev -s $stash_ref)"
    echo "$output" | \grep --color=no '^Dropped'
  else
    echo "$output"
  fi
  _update_git_ctags $ret
  $_git_cmd status --untracked-files=no
  return $ret
}
complete_function gstp git stash pop

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

  $_git_cmd commit -m "Update submodule $1 ${${(ps: :)summary[1]}[3]}"$'\n\n'"    ${(pj:\n    :)summary}" "$1"
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
  hub submodule add "$@" "$sm" "$smpath" && \
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
      && $_git_cmd stash pop -q
    $_git_cmd status --untracked-files=no
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
  local ret
  get_current_branch && echo "$ret"
}
function get_current_branch() {
  local ref
  ref=$($_git_cmd symbolic-ref --quiet HEAD 2> /dev/null)
  local _ret=$?
  if [[ $_ret != 0 ]]; then
    [[ $_ret == 128 ]] && return $_ret  # no git repo.
    ref=$($_git_cmd rev-parse --short HEAD 2> /dev/null) || return $?
  fi
  ret=${ref#refs/heads/}
}

function current_repository() {
  if ! $_git_cmd rev-parse --is-inside-work-tree &> /dev/null; then
    return
  fi
  echo $($_git_cmd remote -v | cut -d':' -f 2)
}

# these aliases take advantage of the previous function
alias ggpull='git pull origin $(current_branch)'
compdef -e 'words=(git pull origin "${(@)words[2,-1]}"); ((CURRENT+=2)); _normal' ggpull

ggpush() {
  local -h remote branch branch_given remote_branch
  local -ha args git_opts

  # Get args (skipping options).
  local using_force=0 dryrun=0
  for i; do
    if [[ $i == -f ]]; then  # use --force-with-lease for -f.
      using_force=1
      i=--force-with-lease
    fi
    [[ $i == --force ]] && using_force=1
    [[ $i == -n || $i == --dry-run ]] && dryrun=1
    [[ $i == -* ]] && git_opts+=($i) || args+=($i)
    [[ $i == -h ]] && { echo "Usage: ggpush [--options...] [remote (Default: tracking branch / github.user)] [branch (Default: current)]"; return; }
  done

  remote=${args[1]}
  if (( $#args > 1 )); then
    branch_given=1
    branch=${args[2]}
    if [[ $branch == *:* ]]; then
      remote_branch=${branch#*:}
      branch=${branch%:*}
    else
      remote_branch=$branch
    fi
  else
    branch_given=0
    branch=$(current_branch)
    if [[ "$branch" = master ]]; then
      # TODO: allow to override?!  But not with -f, which is used already.
      echo "Should not be used for master, exiting." >&2
      return 1
    fi
    remote_branch=$branch
  fi

  if [[ -z $remote ]]; then
    local u=$(\git rev-parse --abbrev-ref '@{u}')
    if [[ -n $u ]]; then
      remote=${u%%/*}
      echo "Using remote from upstream ($u)"
      remote_branch=${u##*/}
    fi
  fi

  if [[ -z $remote ]]; then
    for cfg in my.ggpush-default-remote ggpush.default-remote branch.$branch.pushRemote remote.pushDefault; do
      remote=$($_git_cmd config $cfg)
      if [[ -n $remote ]]; then
        echo "Using remote from $cfg: $remote"
        if [[ $cfg == ggpush.default-remote ]]; then
          echo "ggpush.default-remote is deprecated: use my.ggpush-default-remote instead:" >&2
        fi
        break
      fi
    done

    if [[ -z $remote ]]; then
      local gh_user=$($_git_cmd config github.user)
      if [[ -n $gh_user ]]; then
        # echo "Using remote from github.user: $gh_user"
        local remote=$($_git_cmd remote -v \
          | awk '$2 ~ /github.com[:/]'$gh_user'/ && $3 == "(push)" {print $1; exit}')
        if [[ -n "$remote" ]]; then
          echo "NOTE: using (push) remote for github.user $gh_user: $remote"
        else
          # Verify remote from github.user:
          if [[ "$($_git_cmd ls-remote --get-url $gh_user 2> /dev/null)" \
              != "$gh_user" ]]; then
            remote="$gh_user"
            echo "Using remote from github.user: $gh_user"
          else
            echo "NOTE: remote for github.user does not exist ($gh_user)."
            if (( $dryrun )); then
              echo "dry-run: skipping 'hub fork' etc."
            else
              remote="$gh_user"
              local repo="$($_git_cmd ls-remote --get-url origin)"
              if [[ -n "$repo" ]]; then
                repo=${repo##*/}
              fi
              if curl -s -I "https://github.com/$remote/$repo" \
                  | head -n1 | grep -q 200; then
                echo "Adding remote through hub: $remote"
                hub remote add -p "$remote"
              else
                echo "Forking.."
                hub fork
              fi
            fi
          fi
        fi
      fi
      if [[ -z $remote ]]; then
        echo "ERROR: cannot determine remote."
        return 1
      fi
    fi

    # Ask for confirmation with '-f' and autodetected remote.
    if [[ $using_force == 1 ]]; then
      echo "WARN: using '-f' without explicit remote."
      echo -n "Do you want to continue with detected $remote:$branch? [y/N] "
      read -q || return 1
      echo
    fi

  elif (( ${git_opts[(i)-u]} > ${#git_opts} )); then
    if [[ -z $($_git_cmd rev-parse --verify $branch@{upstream} \
        --symbolic-full-name --abbrev-ref 2>/dev/null) ]]; then
      # No remote given, and nothing configured: use `-u`.
      echo "NOTE: Using '-u' to set upstream."
      git_opts+=(-u)
    fi
  fi

  if [[ -z $branch ]]; then
    echo "No current branch (given or according to 'current_branch').\nAre you maybe in a rebase, or not in a Git repo?"
    return 1
  fi

  local -a cmd
  cmd=(git push $git_opts $remote $branch:$remote_branch)
  echo $cmd
  $=cmd
}
compdef _git ggpush=git-push

ggpushb() {
  ggpush "$@" && hub browse
}
compdef _git ggpushb=git-push
alias gpb='ggpushb --set-upstream'

# these alias ignore changes to file
alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'
# list temporarily ignored files
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
