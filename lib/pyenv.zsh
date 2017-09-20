# My pyenv plugin.
#
# Put into lib/ for now, since it needs to be loaded before the dirstack
# handler (which is done early by now).
#
# Setup pyenv (with completion for zsh).
# Very basic setup is done in ~/.profile, but that does not cover
# completion/functions.
if [[ -d ~/.pyenv ]]; then
  [[ -z "$PYENV_ROOT" ]] && echo "assert: PYENV_ROOT NOT SET.." >&2
  (( $+functions[zsh_setup_pyenv] )) && echo "assert: zsh_setup_pyenv ALREADY SET.." >&2
  (( $+commands[pyenv] )) || echo "assert: pyenv NOT IN PATH.." >&2

  # Setup pyenv completions always.
  # (it is useful to have from the beginning, and using it via zsh_setup_pyenv
  # triggers a job control bug in Zsh).
  source $PYENV_ROOT/completions/pyenv.zsh

  zsh_setup_pyenv() {
    # Manual pyenv init, without "source", which triggers a bug in zsh.
    # Adding shims to $PATH etc has been done already also.
    # eval "$(command pyenv init - --no-rehash | grep -v '^source')"
    export PYENV_SHELL=zsh
    pyenv() {
      local command
      command="$1"
      if [ "$#" -gt 0 ]; then
        shift
      fi

      case "$command" in
        activate|deactivate|rehash|shell|virtualenvwrapper|virtualenvwrapper_lazy)
          eval "`pyenv "sh-$command" "$@"`";;
        *)
          command pyenv "$command" "$@";;
      esac
    }
    export PYENV_VIRTUALENV_DISABLE_PROMPT=1

    unfunction zsh_setup_pyenv
  }
  pyenv() {
    if [[ -n ${commands[pyenv]} ]]; then
      zsh_setup_pyenv
      pyenv "$@"
    fi
  }
fi

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
