setopt noglobalrcs

# PATH handling (both for login, interactive and "other" shells):

# Use wrappers to append/prepend PATH elements only if they are
# missing. This helps to keep VirtualEnv's path at the front.
# (in case of using tmux after `workon`, where each window spawns a new shell)
append_path_if_not_in_already() {
  local i
  for i; do
    (( ${path[(i)$i]} <= ${#path} )) && continue
    path+=($i)
  done
}
prepend_path_if_not_in_already() {
  local i
  for i; do
    (( ${path[(i)$i]} <= ${#path} )) && continue
    path=($i $path)
  done
}

# Add superuser binaries to path
append_path_if_not_in_already /sbin /usr/sbin

# Add GNU coreutils to path on MacOS
if [[ -n $commands[brew] ]]; then
  prepend_path_if_not_in_already $(brew --prefix coreutils)/libexec/gnubin
fi

prepend_path_if_not_in_already /usr/local/bin /usr/local/sbin
prepend_path_if_not_in_already ~/.dotfiles/usr/bin ~/bin
# For pipsi:
prepend_path_if_not_in_already ~/.local/bin

# Add various "bin" directories to $path.
() {
  local i
  for i in ~/.gem/ruby/*/bin(N/) /var/lib/gems/*/bin(N/:A); do
    append_path_if_not_in_already $i
  done
}


# Add specific paths for root; used on diskstation
if [[ $USER == root ]]; then
  for i in /opt/sbin /usr/syno/bin ; do
    test -d $i || continue
    path+=($i)
  done
fi
unset i

# Make path/PATH entries unique. Use '-g' for sourcing it from a function.
typeset -gU path


export GPGKEY='3FE63E00'

# Setup pyenv (with completion for zsh).
# It gets done also in ~/.profile, but that does not cover completion and
# ~/.profile is not sourced for real virtual consoles (VTs).
if [[ -d ~/.pyenv ]] && ! (( $+functions[zsh_setup_pyenv] )); then # only once!
  if ! (( $+PYENV_ROOT )); then
    export PYENV_ROOT="$HOME/.pyenv"
  fi
  # TODO: Prepend paths always?! (https://github.com/yyuu/pyenv/issues/492).
  #       Would allow for using PYENV_VERSION in (Zsh) scripts always.
  #       But already done in ~/.profile?!
  prepend_path_if_not_in_already $PYENV_ROOT/bin
  # Prepend pyenv shims path always, it gets used also for lookup in
  # VIRTUAL_ENV, and ~/.local/bin should not override it (e.g. for vint).
  path=($PYENV_ROOT/shims $path)

  # Setup pyenv completions always.
  # (it is useful to have from the beginning, and using it via zsh_setup_pyenv
  # triggers a job control bug in Zsh).
  source $PYENV_ROOT/completions/pyenv.zsh

  zsh_setup_pyenv() {
    # Manual pyenv init, without "source", which triggers a bug in zsh.
    # Adding shims to $PATH etc has been already also.
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


# Source local env file if any
[ -f ~/.zshenv.local ] && source ~/.zshenv.local
