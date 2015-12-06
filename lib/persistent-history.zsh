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
  date=${(%):-'%D{%F %T.%. (%a)}'}
  cwd="${PWD/#$HOME/~}"
  info=("($$) in $cwd")

  # Detect midnight commander shell and add "(mc)" to info.
  if (( $+MC_SID )); then
    info+=("(mc)")
  fi
  output="== $date $info: $1"

  # Take over expanded version, if different, massaged to be on a single line.
  # TODO: handle newlines better?!
  if [[ $1 != ${3%% } ]] && [[ $1 != ${(pj:; :)${(f)${3%% }}} ]]; then
    # NOTE: do not expand using "(e)", which would expand e.g. `foo`.
    # _zsh_persistent_history_preexec_expanded="${(pj: \\N :)${(e)${3}} -- }"
    _zsh_persistent_history_preexec_expanded="${(pj: \\N :)${3}}"
  else
    _zsh_persistent_history_preexec_expanded=""
  fi
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

  output=$_zsh_persistent_history_preexec_output
  if [ $exitstatus != 0 ]; then
    output+=" [es:$exitstatus]"
  fi
  typeset -F 2 duration
  duration=$(( endtime - _zsh_persistent_history_starttime ))
  if (( duration > 0 )); then
    output+=" [dur:${duration}s]"
    if (( duration > 10 )); then
      output+=" [endtime:${(%):-%D{%T.%.\}}]"
    fi
  fi
  if [[ -n $_zsh_persistent_history_preexec_expanded ]]; then
    # echo "DEBUG: _zsh_persistent_history_preexec_expanded: $_zsh_persistent_history_preexec_expanded"
    output+=" [expanded:$_zsh_persistent_history_preexec_expanded]"
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
