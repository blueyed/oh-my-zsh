# Setup hub function for git, if it is available; http://github.com/defunkt/hub
if [[ -n "$commands[(I)hub]" ]]; then
    eval 'function git(){
        if ! (( $+_has_working_hub  )); then
            hub --version &> /dev/null
            _has_working_hub=$(($? == 0))
        fi
        if (( $_has_working_hub )) ; then
            hub "$@"
        else
            command git "$@"
        fi
        local ret=$?
        # Force vcs_info to be run.
        _ZSH_VCS_INFO_FORCE_GETDATA=1
        return $ret
    }'

    # Extra massaging because of using a function (instead of an alias):

    # Use the git command for vcs_info, instead of hub!
    zstyle ':vcs_info:git:*:-all-' command $(whence -p git)

    # Use hub's compdef for the git function.
    if whence _hub >/dev/null; then
        compdef _hub git
    else
        echo "NOTE: _hub not available for compdef!" >&2
    fi
fi


