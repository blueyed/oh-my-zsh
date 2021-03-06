# Ignore VCS folders (if the necessary grep flags are available).
_setup_grep_alias() {
    local VCS_FOLDERS="{.bzr,.cvs,.git,.hg,.svn}"
    local GREP_OPTIONS
    GREP_OPTIONS=()

    # Is grep argument $1 available?
    grep-flag-available() {
        echo | command grep $1 "" >/dev/null 2>&1
    }
    # Color grep results.
    if grep-flag-available --color=auto; then
        GREP_OPTIONS=(--color=auto)
    fi
    if grep-flag-available --exclude-dir=.cvs; then
        GREP_OPTIONS+=(--exclude-dir=$VCS_FOLDERS)
    elif grep-flag-available --exclude=.cvs; then
        GREP_OPTIONS+=(--exclude=$VCS_FOLDERS)
    fi
    # Clean up.
    unfunction grep-flag-available

    # Remove alias and setup function.
    alias grep="grep ${GREP_OPTIONS}"
    unfunction _setup_grep_alias

    # Run it on first invocation.
    command grep ${GREP_OPTIONS} "$@"
}
alias grep=_setup_grep_alias
