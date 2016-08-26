# Keep a persistent history of all commands executed in a single file/place.
_zsh_persistent_history_logfile=~/.local/share/zsh/history.log

# Enable it by `touch`ing the file:
# % mkdir -m 700 ~/.local/share/zsh && touch ~/.local/share/zsh/history.log
if ! [[ -f $_zsh_persistent_history_logfile ]]; then
  return
fi

zmodload zsh/datetime

alias zhist="lessx $_zsh_persistent_history_logfile"

_zsh_persistent_history_preexec_hook() {
  local -h date cwd info output

  # Skip commands starting with space.
  if [[ "$1" == ' '* ]]; then
    return
  fi

  date=${(%):-'%D{%F %T.%. (%a)}'}
  cwd="${PWD/#$HOME/~}"
  info=("($$) in $cwd")

  # Detect midnight commander shell and add "(mc)" to info.
  if (( $+MC_SID )); then
    info+=("(mc)")
  fi
  local output="== $date $info: $1"

  # Take over expanded version, if different, massaged to be on a single line.
  # TODO: handle newlines better?!
  typeset -g _zsh_persistent_history_preexec_expanded
  local trimmed3=${3%% }
  trimmed3=${trimmed3## }
  local trimmed1=${1%% }
  trimmed1=${trimmed1## }
  if [[ $trimmed1 != $trimmed3 ]] && [[ $trimmed1 != ${(pj:; :)${(f)${trimmed3}}} ]]; then
    # NOTE: do not expand using "(e)", which would expand e.g. `foo`.
    # _zsh_persistent_history_preexec_expanded="${(pj: \\N :)${(e)${3}} -- }"
    _zsh_persistent_history_preexec_expanded="${(pj: \\N :)${3}}"
  else
    _zsh_persistent_history_preexec_expanded=
  fi
  typeset -g _zsh_persistent_history_preexec_output
  typeset -g _zsh_persistent_history_starttime
  _zsh_persistent_history_preexec_output="$output"
  _zsh_persistent_history_starttime=$EPOCHREALTIME
}

_zsh_persistent_history_precmd_hook() {
  # Get exitstatus, first.
  local -h exitstatus=$?
  local -h ret endtime

  # Skip first execution (on shell startup).
  [[ -z $_zsh_persistent_history_preexec_output ]] && return

  endtime=$EPOCHREALTIME

  local output=$_zsh_persistent_history_preexec_output
  if [ $exitstatus != 0 ]; then
    output+=" [es:$exitstatus]"
  fi
  typeset -F 2 duration
  duration=$(( endtime - _zsh_persistent_history_starttime ))
  if (( duration > 0 )); then
    output+=" [dur:${duration}s]"
    if (( duration > 10 )); then
      output+=" [endtime:${(%):-%D{%T.%.}}]"
    fi
  fi
  if [[ -n $_zsh_persistent_history_preexec_expanded ]]; then
    # echo "DEBUG: _zsh_persistent_history_preexec_expanded: $_zsh_persistent_history_preexec_expanded"
    output+=" [expanded:$_zsh_persistent_history_preexec_expanded]"
  fi
  if [[ -n "$MY_X_SESSION_NAME" ]]; then
    output+=" [session:$MY_X_SESSION_NAME]"
  fi
  echo $output >> $_zsh_persistent_history_logfile
  unset _zsh_persistent_history_preexec_output
}

autoload -U add-zsh-hook
add-zsh-hook preexec _zsh_persistent_history_preexec_hook 2>/dev/null || {
  echo 'zsh-syntax-highlighting: failed loading add-zsh-hook.' >&2
}
add-zsh-hook precmd _zsh_persistent_history_precmd_hook 2>/dev/null || {
  echo 'zsh-syntax-highlighting: failed loading add-zsh-hook.' >&2
}
