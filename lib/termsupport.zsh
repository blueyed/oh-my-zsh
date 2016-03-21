# Set terminal window and tab/icon title
#
# usage: title short_tab_title [long_window_title]
#
# See: http://www.faqs.org/docs/Linux-mini/Xterm-Title.html#ss3.1
# Fully supports screen, iterm, and probably most modern xterm and rxvt
# (In screen, only short_tab_title is used)
# NOTES:
#  - '${(%):-%~}' => short PWD, with named dirs
#  - tab title is used by awesomeWM when minimized.
function _title {
  # [[ "$EMACS" == *term* ]] && return
  [[ -z $2 ]] && 2=$1
  1=${(V)${(pj: :)${(f)1}}}
  2=${(V)${(pj: :)${(f)2}}}
  # 1="1:$1"; 2="2:$2"
  # Escape.
  1=${1:gs/%/%%/}
  2=${2:gs/%/%%/}
  # echo "title:1:$1" ; echo "title:2:$2"

  # Append user@host if on ssh.
  if ! (($+TMUX)) && is_remote; then
    # Export it (useful in Vim's titlestring).
    export _TERM_TITLE_SUFFIX=" (${(%):-%n@%m})"
    2+=$_TERM_TITLE_SUFFIX
  fi

  # Container prefix/suffix: {{{
  local PREFIX SUFFIX RELPWD
  # Get OpenVZ container ID (/proc/bc is only on the host):
  if [[ -r /proc/user_beancounters ]]; then
    if [[ ! -d /proc/bc ]]; then
      # container
      PREFIX="[$(hostname)#$(sed -n 3p /proc/user_beancounters | cut -f1 -d: | tr -d '[:space:]')] "
      # SUFFIX=" (${(%):-%~})"
    elif [[ ${PWD:A} == /var/lib/vz/private/[0-9]* ]]; then
      # HN, in container dir
      RELPWD=${${PWD:A}#/var/lib/vz/private/}
      # SUFFIX=" (HN:${RELPWD%%/*}~${RELPWD##[[:digit:]]##/#})"
    fi
  fi
  # SUFFIX=${SUFFIX:- [${${(%):-%~}:gs/%/%%/}]}
  1=$PREFIX$1
  2=$PREFIX$2$SUFFIX
  # }}}

  # prompt_subst is required for print with $''.
  # NOTE: $'' is required for no extra output with: printf "\e[3mCheck for\e[m"
  setopt local_options prompt_subst

  if (($+TMUX)); then
    if [[ $_tmux_name_reset != ${TMUX}_${TMUX_PANE} ]]; then
      # Migrate from previous title handling for running tmux sessions. (2014-10-30)
      if (($+_tmux_title_is_auto_set)); then
        if [[ $_tmux_title_is_auto_set == 1 ]]; then
          local tmux_auto_rename=on
        fi
        unset _tmux_title_is_auto_set
      else
        local tmux_auto_rename=$(tmux show-window-options -t $TMUX_PANE -v automatic-rename 2>/dev/null) || $(tmux show-window-options -t $TMUX_PANE | grep '^automatic-rename' | cut -f2 -d\ )
      fi
      if [[ $tmux_auto_rename != "off" ]]; then
        # echo "Resetting tmux name to 0."
        # Handle old tmux (1.6, diskstation).
        if [ "$(tmux -V)" = 'tmux 1.6' ]; then
          for i in window-status-format window-status-current-format; do
            local cur="$(tmux show-window-options -g | grep "^$i" | cut -d\  -f2-)"
            local new="${cur/0T\} /0T [#W]}"
            if [[ $new == $cur ]]; then
              # Only once
              break
            fi
            new="${new/\#\{?window_name,\[\#W\],/}"
            # Remove quotes
            new=${${new#\"}%\"}
            tmux set -wg $i "$new"
          done
          tmux set-window-option -t $TMUX_PANE automatic-rename off
        else
          tmux set-window-option -t $TMUX_PANE -q automatic-rename off
        fi
        tmux rename-window -t $TMUX_PANE 0
      fi
      export _tmux_name_reset=${TMUX}_${TMUX_PANE}
    fi
  fi

  # ESC]0;stringBEL -- Set icon name and window title to string
  # ESC]1;stringBEL -- Set icon name to string
  # ESC]2;stringBEL -- Set window title to string
  print -Pn $'\e]2;$2\a' # set window name (available as #T in tmux).
  print -Pn $'\e]1;$1\a' # set icon (=tab) name (will override window name on broken terminal)
}
# Manually set the title and disable autosetting it.
title() {
  _title $1 $2
  export DISABLE_AUTO_TITLE=true
}

ZSH_THEME_TERM_TAB_TITLE_IDLE="%15<…<%~%<<_" # 15 char left truncated PWD.
ZSH_THEME_TERM_TITLE_IDLE="⩫ %~_"

# Runs before showing the prompt
function omz_termsupport_precmd {
  [ "$DISABLE_AUTO_TITLE" != "true" ] || return

  if (( $+_ZSH_LAST_CMD_TITLE )); then
    local suffix=" ($_ZSH_LAST_CMD_TITLE)"
  else
    local suffix=""
  fi

  _title ${(%)ZSH_THEME_TERM_TAB_TITLE_IDLE}${suffix} \
        ${(%)ZSH_THEME_TERM_TITLE_IDLE}${suffix}
}

# Resolve resumed jobs (`fg`), used in title and _force_vcs_info_preexec.
# Sets $_zsh_resolved_jobspec.
typeset -g _zsh_resolved_jobspec
_expand_jobspec_via_jobtexts_preexec() {
  local -a typed; typed=(${(z)1}) # split what the user has typed into words using shell parsing
  # Resolve jobspecs, e.g. when "fg" or "%-" is used:
  local jobspec

  # # Needed here, or in omz_termsupport_preexec?!
  # emulate -L zsh
  # setopt localoptions extended_glob

  _zsh_resolved_jobspec=()
  if [[ $typed[1] == fg ]] ; then
    # Set typed to jobtext for first argument. If there are more, add "(+x jobs)".
    # Use jobspec from $typed[2] if not empty and it does not start with "[;&|]" (starting next command)
    if [[ -n "$typed[2]" ]] && [[ $typed[2] != [\;\&\|]* ]]; then
      jobspec=${typed[2]}
    else
      jobspec='%+'
    fi
    (( ${+jobtexts[$jobspec]} )) \
      && _zsh_resolved_jobspec=${(z)${jobtexts[$jobspec]}}
  elif [[ $typed[1] == %* ]] && (( $+jobtexts[$typed[1]] )); then
    jobspec=$typed[1]
    _zsh_resolved_jobspec=${(z)${jobtexts[$jobspec]}}
  fi
}

# Runs before executing the command
function omz_termsupport_preexec {
  if [[ "$DISABLE_AUTO_TITLE" == "true" ]]; then
    return
  fi

  local -a typed; typed=(${(z)1}) # split what the user has typed into words using shell parsing

  if (( $#_zsh_resolved_jobspec )); then
    typed=(${(z)_zsh_resolved_jobspec})
  fi

  # Get the cmd out of what was typed:
  # Get the index of the first item not matching the list.
  local cmd_index=${typed[(wi)^(export|*?=*|sudo|ssh|-*|;|\[*)]} # cmd name only, or if this is sudo or ssh, the next cmd
  # printf 'typed: "%s"\n' $typed; echo $cmd_index; read
  local CMD="$typed[$cmd_index]"

  # For special cases like "make", append the arg.
  local -a cmds_with_arg
  cmds_with_arg=(make man ve)
  if (( $#typed > $cmd_index )) && [[ $typed[$cmd_index+1] != ';' ]]; then
    if (( $#CMD <= 4 )) || (( ${cmds_with_arg[(i)$CMD]} <= ${#cmds_with_arg} )); then
      CMD+=" $typed[$((++cmd_index))]"
    fi
  fi
  if (( $#typed > $cmd_index )); then
    CMD+=" …"
  fi
  # local window_name="$CMD [${(%):-%~}]"
  # local window_name="$CMD"
  local window_title="${typed}"
  # append cwd to window title
  window_title+=" [${(%):-%~}]"
  export _ZSH_LAST_CMD_TITLE=$window_title  # used in omz_termsupport_precmd.

  # NOTE: tab/icon name is used by awesomeWM when minimized.
  _title $window_title $window_title # let the terminal app itself handle cropping
}

autoload -U add-zsh-hook
add-zsh-hook precmd  omz_termsupport_precmd
add-zsh-hook preexec _expand_jobspec_via_jobtexts_preexec
add-zsh-hook preexec omz_termsupport_preexec
