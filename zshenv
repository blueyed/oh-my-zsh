setopt noglobalrcs

# PATH handling (both for login, interactive and "other" shells):

# Use wrappers to append/prepend PATH elements only if they are
# missing. This helps to keep VirtualEnv's path at the front.
# (in case of using tmux after `workon`, where each window spawns a new shell)
append_path_if_not_in_already() {
  for i; do
    # echo "Check: $i" >> /tmp/O
    (( ${path[(i)$i]} <= ${#path} )) && continue
    # echo "Add: $i" >> /tmp/O
    path+=($i)
  done
}
prepend_path_if_not_in_already() {
  for i; do
    # echo "Check: $i" >> /tmp/O
    (( ${path[(i)$i]} <= ${#path} )) && continue
    # echo "Prepend: $i" >> /tmp/O
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
if [[ -d ~/.pyenv ]] && ! (( $+functions[_pyenv_setup] )); then # only once!
  export PYENV_ROOT="$HOME/.pyenv"
  prepend_path_if_not_in_already $PYENV_ROOT/bin
  prepend_path_if_not_in_already $PYENV_ROOT/shims

  # Setup pyenv completions always.
  # (it is useful to have from the beginning, and using it via _pyenv_setup
  # triggers a job control bug in Zsh).
  source $PYENV_ROOT/completions/pyenv.zsh

  _ZSH_PYENV_SETUP=0  # used in prompt.
  _pyenv_setup() {
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

    eval "$(pyenv virtualenv-init -)"

    _ZSH_PYENV_SETUP=1
    unfunction _pyenv_setup
  }
  pyenv() {
    if [ -n "$commands[pyenv]" ] ; then
      _pyenv_setup
      pyenv "$@"
    fi
  }
fi


# Source local env file if any
[ -f ~/.zshenv.local ] && source ~/.zshenv.local
