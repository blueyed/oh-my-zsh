# blueyed's theme for zsh
# # TODO: to interface with zsh's promptinit, move this to prompt_blueyed_setup function / file.
#
# Features:
#  - color hostnames according to its hashed value (see color_for_host)
#
# Origin:
#  - Based on http://kriener.org/articles/2009/06/04/zsh-prompt-magic
#  - Some Git ideas from http://eseth.org/2010/git-in-zsh.html (+vi-git-stash, +vi-git-st, ..)
#
# Some signs/symbols: ✚ ⬆ ⬇ ✖ ✱ ➜ ✭ ═ ◼ ♺ ❮ ❯ λ ↳
# See also: http://jrgraphix.net/r/Unicode/2600-26FF
#
#
# TODO: setup $prompt_cwd in chpwd hook only (currently adding the hook causes infinite recursion via vcs_info)
# NOTE: prezto's git-info: https://github.com/sorin-ionescu/prezto/blob/master/modules/git/functions/git-info#L202

autoload -U add-zsh-hook
autoload -Uz vcs_info
autoload -U is-at-least

setopt no_prompt_subst  # No code execution via Git commit messages! (http://www.zsh.org/mla/workers/2014/msg01189.html)

# Ensure that the prompt is redrawn when the terminal size changes (SIGWINCH).
# Taken from plugins/vi-mode/vi-mode.plugin.zsh, and bart's prompt.
prompt_blueyed_winch() {
    setopt localoptions nolocaltraps noksharrays unset

    # Delete ourself from TRAPWINCH if not using our precmd.
    if [[ $precmd_functions = *prompt_blueyed_precmd* ]]; then
        zle && { zle reset-prompt; zle -R }
    else
        functions[TRAPWINCH]="${functions[TRAPWINCH]//prompt_blueyed_winch}"
    fi
}
# Paste our special command into TRAPWINCH.
# functions[TRAPWINCH]="${functions[TRAPWINCH]//prompt_blueyed_winch}
#     prompt_blueyed_winch"

# Query/use custom command for `git`.
# See also ../plugins/git/git.plugin.zsh
zstyle -s ":vcs_info:git:*:-all-" "command" _git_cmd || _git_cmd=$(whence -p git)

# Skip prompt setup in virtualenv/bin/activate.
# This causes a glitch with `pyenv shell venv_name` when it gets activated.
VIRTUAL_ENV_DISABLE_PROMPT=1

PR_RESET="%{${reset_color}%}"

# SSH conection?
is_ssh() {
    (( $+SSH_CLIENT )) && return
    if ! (( $+_ZSH_IS_SSH )); then
        [[ "$(who am i | cut -f2  -d\( | cut -f1 -d:)" != "" ]]
        _ZSH_IS_SSH=$?
    fi
    return $_ZSH_IS_SSH
}
# Remote system?
is_remote() {
    is_ssh || [[ -e /proc/user_beancounters && ! -d /proc/bc ]]
}

# Remove any ANSI color codes (via www.commandlinefu.com/commands/view/3584/)
_strip_escape_codes() {
    [[ -n $commands[gsed] ]] && sed=gsed || sed=sed # gsed with coreutils on MacOS
    # XXX: does not work with MacOS default sed either?!
    # echo "${(%)1}" | sed "s/\x1B\[\([0-9]\{1,3\}\(;[0-9]\{1,3\}\)?\)?[m|K]//g"
    # echo "${(%)1}" | $sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})?)?[m|K]//g"
    # NOTE: fails with sed on busybox (BusyBox v1.16.1).
    echo $1 | $sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})?)?[m|K]//g"
}

# Via http://stackoverflow.com/a/10564427/15690.
# NOTE: it could use `setopt localoptions nopromptsubst`, but it is meant to
# be used in a prompt, and not for removing ANSI escape codes only.
get_visible_length() {
    local zero='%([BSUbfksu]|([FB]|){*})'
    print ${#${(S%%)1//$~zero}}
}

is_urxvt() {
    [[ $TERM == rxvt* ]] || [[ $COLORTERM == rxvt* ]]
}

# Check if we're running in gnome-terminal.
# This gets used to e.g. auto-switch the profile.
is_gnome_terminal() {
    # Common case, since I am using URxvt now.
    is_urxvt && return 1
    # Old-style, got dropped.. :/
    if [[ -n $COLORTERM ]]; then
        [[ $COLORTERM == "gnome-terminal" ]] && return 0 || return 1
    fi
    (( $+KONSOLE_PROFILE_NAME )) && return 1
    # Check /proc, but only on the local system.
    if [[ -z $SSH_CLIENT ]]; then
        # Fallback to `ps` if /proc does not exist.
        local parentcmd
        if [[ -f /proc/$PPID/cmdline ]]; then
            parentcmd="$(</proc/$PPID/cmdline)"
        else
            parentcmd="$(ps -ocommand= -p $PPID)"
        fi
        [[ ${parentcmd:t} == gnome-terminal* ]]
        return
    fi
    return 1
}


# Get the .git dir (cached).
# Not uses anymore currently.
my_get_gitdir() {
    local base=$1
    if [[ -z $base ]]; then
        if (( ${+_zsh_cache_pwd[gitdir_base]} )) \
            && [[ -e ${_zsh_cache_pwd[gitdir_base]} ]]; then
            base=${_zsh_cache_pwd[gitdir_base]}
        else
            base=$($_git_cmd rev-parse --show-toplevel 2>/dev/null) || return
            _zsh_cache_pwd[gitdir_base]=base
        fi
    fi

    if (( ${+_zsh_cache_pwd[gitdir_$base]} )) \
        && [[ -e ${_zsh_cache_pwd[gitdir_$base]} ]]; then
        echo ${_zsh_cache_pwd[gitdir_$base]}
        return
    fi

    local gitdir=$base/.git
    if [[ -f $gitdir ]]; then
        # XXX: the output might be across two lines (fixed in the meantime); handled/fixed that somewhere else already, but could not find it.
        gitdir=$($_git_cmd rev-parse --resolve-git-dir $gitdir | head -n1)
    fi
    _zsh_cache_pwd[gitdir_$base]=$gitdir
    echo $gitdir
}

# Setup MY_X_THEME_VARIANT.
eval "$(~/.dotfiles/usr/bin/sh-setup-x-theme)"
theme_variant() {
    # setopt localoptions
    if [[ "$1" == "-q" ]]; then
        ~/.dotfiles/usr/bin/sh-setup-x-theme -q
    else
        eval "$(~/.dotfiles/usr/bin/sh-setup-x-theme "$@")"
    fi
}
compdef -e '_arguments "1: :(auto light dark)" "2: :(save)"' theme_variant


# Override builtin reset-prompt widget to call the precmd hook manually
# (for fzf's fzf-cd-widget). This is needed in case the pwd changed.
# TODO: move cwd related things from prompt_blueyed_precmd into a chpwd hook?!
zle -N reset-prompt my-reset-prompt
function my-reset-prompt() {
    if (( ${+precmd_functions[(r)prompt_blueyed_precmd]} )); then
        prompt_blueyed_precmd reset-prompt
    fi
    zle .reset-prompt
}

# NOTE: using only prompt_blueyed_precmd as the 2nd function fails to add it, when added as 2nd one!
setup_prompt_blueyed() {
    add-zsh-hook precmd prompt_blueyed_precmd
}
unsetup_prompt_blueyed() {
    add-zsh-hook -d precmd prompt_blueyed_precmd
}
setup_prompt_blueyed

# Optional arg 1: "reset-prompt" if called via reset-prompt zle widget.
prompt_blueyed_precmd () {
    # Get exit status of command first.
    local -h save_exitstatus=$?

    if [[ $1 == "reset-prompt" ]]; then
        if [[ $PWD == $_ZSH_LAST_PWD ]]; then
            # cwd did not change, nothing to do.
            return
        fi
    else
        _ZSH_LAST_EXIT_STATUS=$save_exitstatus
    fi
    _ZSH_LAST_PWD=$PWD

    # Start profiling, via http://stackoverflow.com/questions/4351244/can-i-profile-my-zshrc-zshenv
      # PS4='+$(date "+%s:%N") %N:%i> '
      # exec 3>&2 2>/tmp/startlog.$$
      # setopt xtrace

    # FYI: list of colors: cyan, white, yellow, magenta, black, blue, red, default, grey, green
    # See `colors-table` for a list.
    local -h exitstatus=$_ZSH_LAST_EXIT_STATUS
    local -h    normtext="%{$fg_no_bold[default]%}"
    local -h      hitext="%{$fg_bold[magenta]%}"
    local -h    venvtext="%{$fg_bold[magenta]%}"
    local -h    histtext="$normtext"
    local -h  distrotext="%{$fg_bold[green]%}"
    local -h  jobstext_s="%{$fg_bold[magenta]%}"
    local -h  jobstext_r="%{$fg_bold[magenta]%}"
    local -h exiterrtext="%{$fg_no_bold[red]%}"
    local -h        blue="%{$fg_no_bold[blue]%}"
    local -h     cwdtext="%{$fg_no_bold[default]%}"
    local -h   nonrwtext="%{$fg_no_bold[red]%}"
    local -h    warntext="%{$fg_bold[red]%}"
    local -h    roottext="%{$fg_no_bold[yellow]%}"
    local -h    repotext="%{$fg_no_bold[green]%}"
    local -h     invtext="%{$fg_bold[cyan]%}"
    local -h   alerttext="%{$fg_no_bold[red]%}"
    local -h     rprompt="$normtext"
    local -h   rprompthl="%{$fg_bold[default]%}"
    local -h  prompttext="%{$fg_no_bold[green]%}"
    if [[ $MY_X_THEME_VARIANT == "light" ]]; then
        local -h   dimmedtext="%{$fg_no_bold[white]%}"
    else
        local -h   dimmedtext="%{$fg_no_bold[black]%}"
    fi
    local -h bracket_open="${dimmedtext}["
    local -h bracket_close="${dimmedtext}]"
    local -h listdelimitter="${dimmedtext}|"

    local -h prompt_cwd prompt_vcs cwd
    local -ah prompt_extra rprompt_extra RPS1_list
    # Optional parts for rprompt; skipped, if they would cause a linebreak.
    typeset -a rprompt_extra_optional

    prompt_vcs=""
    # Check for exported GIT_DIR (used when working on bup backups).
    # Force usage of vcs_info then, also on slow dirs.
    if [[ ${(t)GIT_DIR} == *-export* ]]; then
        prompt_vcs+="${warntext}GIT_DIR! "
    fi
    if [[ -n $prompt_vcs ]] || ! (( $ZSH_IS_SLOW_DIR )) \
            && vcs_info 'prompt'; then
        prompt_vcs+="$vcs_info_msg_0_"
        if ! zstyle -t ':vcs_info:*:prompt:*' 'check-for-changes'; then
            prompt_vcs+=' ?'
        fi

        # Pick up any info from preexec and vcs_info hooks.
        if [[ -n $_zsh_prompt_vcs_info ]]; then
            RPS1_list+=($_zsh_prompt_vcs_info)
            _zsh_prompt_vcs_info=()
        fi

        if [[ -n ${vcs_info_msg_1_} ]]; then
            # "misc" vcs info (via hook_com[misc]), e.g. "shallow".
            rprompt_extra+=($vcs_info_msg_1_)
        fi
    fi

    # Shorten named/hashed dirs.
    cwd=${(%):-%~} # 'print -P "%~"'

    # Highlight different types in segments of $cwd
    local ln_color=${${(ps/:/)LS_COLORS}[(r)ln=*]#ln=}
    # Fallback to default, if "target" is used
    [ "$ln_color" = "target" ] && ln_color="01;36"
    [[ -z $ln_color ]] && ln_color="%{${fg_bold[cyan]}%}" || ln_color="%{"$'\e'"[${ln_color}m%}"
    local cur color color_off i cwd_split
    local -a colored
    if [[ $cwd == '/' ]]; then
        cwd=${nonrwtext}/
    else
        # split $cwd at '/'
        cwd_split=(${(ps:/:)${cwd}})
        if [[ $cwd[1] == '/' ]]; then
            # starting at root
            cur='/'
        fi

        setopt localoptions no_nomatch
        local n=0
        for i in $cwd_split; do
            n=$(($n+1))

            # Expand "~" to make the "-h" test work.
            cur+=${~i}

            # Use a special symbol for "/home".
            if [[ $n == 1 ]]; then
                if [[ $i == 'home' ]]; then
                    i='⌂'
                elif [[ $i[1] != '~' ]]; then
                    i="/$i"
                fi
            fi

            color= color_off=
            # color repository root
            if [[ "$cur" = $vcs_info_msg_2_ ]]; then
                color=${repotext}
            # color Git repo (not root according to vcs_info then)
            elif [[ -e $cur/.git ]]; then
                color=${repotext}
            # color non-existing segment
            elif [[ ! -e $cur ]]; then
                color=${warntext}
            # color non-writable segment
            elif [[ ! -w $cur ]]; then
                color=${nonrwtext}
            else
                color=${normtext}
            fi
            # Symlink: underlined.
            if [[ -h $cur ]]; then
                color+="%U"
                color_off="%u"
            fi
            if ! (( $#color )); then
                color=${cwdtext}
            fi
            colored+=(${color}${i:gs/%/%%/}${color_off})
            cur+='/'
        done
        cwd=${(pj:/:)colored}
    fi

    # Display repo and shortened revision as of vcs_info, if available.
    if [[ -n $vcs_info_msg_3_ ]]; then
        rprompt_extra+=("${repotext}@${vcs_info_msg_3_}")
    fi

    # TODO: if cwd is too long for COLUMNS-restofprompt, cut longest parts of cwd
    #prompt_cwd="${hitext}%B%50<..<${cwd}%<<%b"
    prompt_cwd="${PR_RESET}❮ ${cwd} ${PR_RESET}❯"

    # user@host for SSH connections or when inside an OpenVZ container.
    local remote
    is_remote && remote=1 || remote=0

    local user
    if [[ $UID == 0 ]]; then
        user="${roottext}%n"
    elif (( $remote )); then
        if [[ $UID == 1000 ]]; then
            user="%{${fg_no_bold[green]}%}%n"
        else
            user="%(#.$roottext.$normtext)%n"
        fi
    fi

    local host
    if (( $remote )); then  # Remote (SSH) or OpenVZ?
        host="%{${fg_no_bold[$(color_for_host)]}%}%m"
    fi

    local userathost=$user
    if [[ -n $user ]]; then
        if [[ -z $http_proxy ]]; then
            userathost+="${hitext}@"
        elif [[ -n $host ]]; then
            userathost+="${normtext}@"
        fi
    fi
    userathost+=$host


    # Debian chroot
    if [[ -z $debian_chroot ]] && [[ -r /etc/debian_chroot ]]; then
        debian_chroot="$(</etc/debian_chroot)"
    fi
    if [[ -n $debian_chroot ]]; then
        prompt_extra+=("${normtext}(dch:$debian_chroot)")
    fi
    # OpenVZ container ID (/proc/bc is only on the host):
    if [[ -r /proc/user_beancounters && ! -d /proc/bc ]]; then
        prompt_extra+=("${normtext}[CTID:$(sed -n 3p /proc/user_beancounters | cut -f1 -d: | tr -d '[:space:]')]")
    fi

    _get_pyenv_version() {
        if ! (( $+_zsh_cache_pwd[pyenv_version] )); then
            # Call _pyenv_setup, if it's still defined (not being called yet).
            # This avoids calling it for both subshells below.
            if (( $+functions[_pyenv_setup] )); then
                _pyenv_setup
            fi
            _zsh_cache_pwd[pyenv_version]=$(pyenv version-name)
            _zsh_cache_pwd[pyenv_global]=${(pj+:+)${(f)"$(pyenv global)"}}
        fi
    }

    # virtualenv
    if [[ -n $VIRTUAL_ENV ]]; then
        if ! (( $path[(I)$VIRTUAL_ENV/bin] )); then
            # VIRTUAL_ENV not in $PATH, might be from pyenv.
            _get_pyenv_version
            local v venv_found
            for v in ${(s~:~)_zsh_cache_pwd[pyenv_version]}; do
                if [[ ${VIRTUAL_ENV##*/} == $v ]]; then
                    prompt_extra+=("${venvtext}ⓔ ${VIRTUAL_ENV##*/}")
                    venv_found=1
                    break
                fi
            done
            if [[ -z $venv_found ]]; then
                # VIRTUAL_ENV set, but not in path and not pyenv's name: add a note.
                prompt_extra+=("${venvtext}ⓔ ${VIRTUAL_ENV##*/} (NOT_IN_PATH)")
            fi
        else
            prompt_extra+=("${venvtext}ⓔ ${VIRTUAL_ENV##*/}")
        fi
    fi

    local pyenv_version
    if [[ ${(t)PYENV_VERSION} == *-export* ]]; then
        pyenv_version=${PYENV_VERSION}
    else
        if ! (( $_ZSH_PYENV_SETUP )); then
            # Skip calling pyenv, if it hasn't been used already.
            pyenv_version=?
        else
            _get_pyenv_version
            pyenv_version=${_zsh_cache_pwd[pyenv_version]}
        fi
    fi
    local pyenv_prompt
    if [[ $pyenv_version != ${_zsh_cache_pwd[pyenv_global]} ]]; then
        if [[ ${VIRTUAL_ENV##*/} == $pyenv_version ]]; then
            pyenv_version=✓
        fi
        pyenv_prompt=("${normtext}🐍 ${pyenv_version}")
        RPS1_list+=($pyenv_prompt)
    fi

    # .env file (via https://github.com/Tarrasch/zsh-autoenv).
    if [[ -n $autoenv_env_file ]]; then
        local env_dir=${(D)${${autoenv_env_file:h}%$PWD}}
        if [[ -z $env_dir ]]; then
            RPS1_list+=("${rprompt}.env")
        else
            RPS1_list+=("${rprompt}.env:${env_dir}")
        fi
    fi

    if [[ -n $ENVSHELL ]]; then
        prompt_extra+=("${rprompthl}ENVSHELL:${normtext}${ENVSHELL##*/}")
    # ENVDIR (used for tmm, ':A:t' means tail of absolute path).
    # Only display it when not in an envshell already.
    elif [[ -n $ENVDIR ]]; then
        rprompt_extra+=("${rprompt}envdir:${ENVDIR:A:t}")
    elif [[ ${(t)ENV} == *-export* ]]; then
        rprompt_extra+=("${rprompt}ENV:${ENV}")
    fi

    # Django: django-configurations.
    if [[ -n $DJANGO_CONFIGURATION ]]; then
        rprompt_extra+=("${rprompt}djc:$DJANGO_CONFIGURATION")
    fi
    # Django: settings module.
    if [[ -n $DJANGO_SETTINGS_MODULE ]]; then
        if [[ $DJANGO_SETTINGS_MODULE != 'config.settings' ]] && \
            [[ $DJANGO_SETTINGS_MODULE != 'project.settings.local' ]]; then
            rprompt_extra+=("${rprompt}djs:${DJANGO_SETTINGS_MODULE##*.}")
        fi
    fi

    # Shell level: display it if >= 1 (but substract tmux/tmuxifier levels).
    local disp_SHLVL=$((SHLVL - $+TMUX - ($+TMUXIFIER * 2)))
    if (( disp_SHLVL > 1 )); then
        rprompt_extra+=("%fSHLVL:${disp_SHLVL}")
    fi

    if (( $+MC_SID )); then
        prompt_extra+=("$normtext(mc)")
    fi

    # exit status
    local -h disp
    if [[ $exitstatus -ne 0 ]] ; then
        disp="es:$exitstatus"
        if [ $exitstatus -gt 128 -a $exitstatus -lt 163 ] ; then
            disp+=" (SIG$signals[$exitstatus-128])"
        fi
        # TODO: might make this informative only (to the right) and use a different prompt sign color to indicate $? != 0
        prompt_extra+=("${exiterrtext}${disp}")
    fi

    # Running and suspended jobs, parsed via $jobstates
    local -h jobstatus=""
    if [ ${#jobstates} -ne 0 ] ; then
        local suspended=${#${jobstates[(R)suspended*]}}
        local running=${#${jobstates[(R)running*]}}
        [[ $suspended -gt 0 ]] && jobstatus+="${jobstext_s}${suspended}s"
        [[ $running -gt 0 ]] && jobstatus+="${jobstext_r}${running}r"
        [[ -z $jobstatus ]] || prompt_extra+=("${normtext}jobs:${jobstatus}")
    fi

    # local -h    prefix="%{$normtext%}❤ "

    # tmux pane / identifier
    # [[ -n "$TMUX_PANE" ]] && rprompt_extra+=("${TMUX_PANE//\%/%%}")

    # History number.
    rprompt_extra_optional+=("${normtext}!${histtext}%!")
    # Time.
    rprompt_extra_optional+=("${normtext}⌚ %*")

    # whitespace and reset for extra prompts if non-empty:
    local join_with="${bracket_close}${bracket_open}"
    [[ -n $prompt_extra ]]  &&  prompt_extra="${(pj: :)prompt_extra}"
    [[ -n $rprompt_extra ]] && rprompt_extra="${(pj: :)rprompt_extra}"

    # Assemble prompt:
    local -h prompt="${userathost:+$userathost }${prompt_cwd}${prompt_extra:+ $prompt_extra} "
    local -h rprompt="${rprompt_extra}"

    # Attach $rprompt to $prompt, aligned to $COLUMNS.
    local -h prompt_len=$(get_visible_length $prompt)
    local -h rprompt_len=$(get_visible_length $rprompt)

    local char_hr="―"
    local fillbar_len=$((COLUMNS - (rprompt_len + prompt_len)))

    if (( fillbar_len > 3 )); then
        # There is room for a hr-prefix.
        prompt="${char_hr}${char_hr} ${prompt}"
        (( prompt_len += 3 ))
        (( fillbar_len -= 3))
    fi

    # Add optional parts to rprompt or RPS1.
    if [[ -n $rprompt_extra_optional ]]; then
        local len add
        for i in ${rprompt_extra_optional}; do
            add=" $i"
            len=$(get_visible_length $add)
            if (( $prompt_len + $rprompt_len + $len < $COLUMNS )); then
                rprompt+="$add"
                (( rprompt_len += len ))
                (( fillbar_len -= len ))
            else
                # Fallback: add it to RPS1.
                RPS1_list+=($i)
            fi
        done
    fi

    # Dynamically adjusted fillbar, via SIGWINCH / zle reset-prompt.
    # NOTE: -1 offset is used to fix redrawing issues after (un)maximizing,
    # when the screen is filled (the last line(s) get overwritten, and moves to the top).
    # NOTE: (p) flag and use of $char_hr works in 5.0.8+ only.
    PR_FILLBAR="$PR_RESET${(l~(COLUMNS-($rprompt_len + $prompt_len)-1 < 0 ? 0 : COLUMNS-($rprompt_len + $prompt_len)-1)~~―~)}"

    local -h prompt_sign="%{%(?.${fg_no_bold[blue]}.${fg_no_bold[red]})%}❯%{%(#.${roottext}.${prompttext})%}❯"

    prompt_vcs=${repotext}${${prompt_vcs/#git:/ λ }%% #}

    PS1="${PR_RESET}${prompt}${PR_FILLBAR}${rprompt}
${prompt_vcs}${prompt_sign} ${PR_RESET}"

    # When invoked from gvim ('zsh -i') make it less hurting
    if [[ -n $MYGVIMRC ]]; then
        PS1=$(_strip_escape_codes $PS1)
    fi

    # Assemble RPS1 (different from rprompt, which is right-aligned in PS1).
    if ! (( $+MC_SID )); then  # Skip for midnight commander: display issues.
        # Distribution (if on a remote system)
        if is_remote; then
            RPS1_list=("$distrotext$(get_distro)" $RPS1_list)
        fi

        # Keymap indicator for dumb terminals.
        if [ -n ${_ZSH_KEYMAP_INDICATOR} ]; then
            RPS1_list=("${_ZSH_KEYMAP_INDICATOR}" $RPS1_list)
        fi

        RPS1_list=("${(@)RPS1_list:#}") # remove empty elements (after ":#")
        # NOTE: PR_RESET without space might cause off-by-one error with urxvt after `ls <tab>` etc.
        if (( $#RPS1_list )); then
            if is-at-least 5.0.8; then
                RPS1="${(pj:$listdelimitter:)RPS1_list}$PR_RESET "
            else
                RPS1="${(pj: :)RPS1_list}$PR_RESET "
            fi
        else
            RPS1=
        fi
    fi

    # End profiling
    # unsetopt xtrace
    # exec 2>&3 3>&-
}

# Cache for values based on current working directory.
typeset -g -A _zsh_cache_pwd
_zsh_cache_pwd_chpwd() {
    _zsh_cache_pwd=()
}
add-zsh-hook chpwd _zsh_cache_pwd_chpwd


# Register vcs_info hooks.
zstyle ':vcs_info:git*+set-message:*' hooks git-stash git-st git-untracked git-shallow



# Show count of stashed changes.
function +vi-git-stash() {
    [[ $1 == 0 ]] || return  # do this only once for vcs_info_msg_0_.

    # Return if check-for-changes is false:
    if ! zstyle -t ':vcs_info:*:prompt:*' 'check-for-changes'; then
        hook_com[misc]+="$hitext☰ ?"
        return
    fi

    if [[ -s ${vcs_comm[gitdir]}/refs/stash ]] ; then
        local -a stashes
        # Get stashes as array, with subject and (relative) date per line.
        stashes=(${(ps:\n\n:)"$($_git_cmd --git-dir="${vcs_comm[gitdir]}" \
            stash list --pretty=format:%s%n%cr%n)"})

        if (( $#stashes )); then
            # Display a different icon based on where the stash is from.
            local top_stash_branch
            # Format: WIP on persistent-tag-properties: 472e3b1 Handle persistent tag layout in tag.new
            top_stash_branch="${${${stashes[1]}#(WIP\ on|On)\ }%%:*}"
            if [[ $top_stash_branch == $hook_com[branch] ]]; then
                hook_com[misc]+="$hitext☶ "
            else
                hook_com[misc]+="$hitext☵ "
            fi

            # Add number of stashes, if more than one.
            if (( $#stashes > 1 )); then
                hook_com[misc]+="✖${#stashes}"
            fi

            # Display shortened, relative time of top stash.
            typeset -a top_stash_time
            top_stash_time=(${(s: :)${(f)stashes[1]}[2]})
            local short_time_unit=${top_stash_time[2][1]}
            if [[ $short_time_unit != s ]]; then
                if [[ $short_time_unit == m && ${top_stash_time[2][2]} == o ]]; then
                    # Handle "minutes" and "months".
                    short_time_unit+=${top_stash_time[2][2]}
                fi
                hook_com[misc]+="$normtext(${top_stash_time[1]}$short_time_unit)"
            fi
        fi
    fi
    return
}

# vcs_info: git: Show marker (✗) if there are untracked files in repository.
# (via %c).
function +vi-git-untracked() {
    [[ $1 == 0 ]] || return  # do this only once for vcs_info_msg_0_.

    local gitdir=${vcs_comm[gitdir]}

    if [[ $($_git_cmd rev-parse --is-bare-repository) == true ]]; then
        hook_com[staged]+='[bare] '
    elif $_git_cmd --git-dir $gitdir ls-files --other --directory \
            --exclude-standard | command grep -q .; then
        hook_com[staged]+='✗ '
    fi
}

# vcs_info: git: Show marker if the repo is a shallow clone.
# (via %c).
function +vi-git-shallow() {
    [[ $1 == 0 ]] || return 0 # do this only once for vcs_info_msg_0_.

    if [[ -f ${vcs_comm[gitdir]}/shallow ]]; then
        hook_com[misc]+="${hitext}㿼 "
    fi
}

# Show remote ref name and number of commits ahead-of or behind.
# This also colors and adjusts ${hook_com[branch]}.
function +vi-git-st() {
    [[ $1 == 0 ]] || return 0 # do this only once for vcs_info_msg_0_.

    local ahead_and_behind_cmd ahead_and_behind
    local ahead behind remote
    local branch_color remote_color local_branch local_branch_disp
    local -a gitstatus

    # # return if check-for-changes is false:
    # if ! zstyle -t ':vcs_info:*:prompt:*' 'check-for-changes'; then
    #     return 0
    # fi

    # NOTE: "branch" might come shortened as "$COMMIT[0,7]..." from Zsh.
    #       (gitbranch="${${"$(< $gitdir/HEAD)"}[1,7]}…").
    local_branch=${hook_com[branch]}

    # Are we on a remote-tracking branch?
    remote=${$($_git_cmd rev-parse --verify ${local_branch}@{upstream} \
        --abbrev-ref 2>/dev/null)}

    # Init local_branch_disp: shorten branch.
    if [[ $local_branch == bisect/* ]]; then
        local_branch_disp="-"
    elif (( $#local_branch > 21 )) && ! [[ $local_branch == */* ]]; then
        local_branch_disp="${local_branch:0:20}…"
    else
        local_branch_disp=$local_branch
    fi

    # Make branch name bold if not "master".
    [[ $local_branch == "master" ]] \
        && branch_color="%{$fg_no_bold[blue]%}" \
        || branch_color="%{$fg_bold[blue]%}"

    if [[ -z ${remote} ]] ; then
        hook_com[branch]="${branch_color}${local_branch_disp}"
        return 0
    fi

    # Handle remote tracking branches.

    # for git prior to 1.7
    # ahead=$($_git_cmd rev-list origin/${hook_com[branch]}..HEAD | wc -l)

    # Gets the commit difference counts between local and remote.
    ahead_and_behind_cmd="$_git_cmd rev-list --count --left-right HEAD...@{upstream}"
    # Get ahead and behind counts.
    ahead_and_behind="$(${(z)ahead_and_behind_cmd} 2> /dev/null)"

    ahead="$ahead_and_behind[(w)1]"
    (( $ahead )) && gitstatus+=( "${normtext}+${ahead}" )

    behind="$ahead_and_behind[(w)2]"
    (( $behind )) && gitstatus+=( "${alerttext}-${behind}" )

    remote=${remote%/$local_branch}

    # Abbreviate "master@origin" to "m@o" (common/normal).
    if [[ $remote == "origin" ]] ; then
      remote=o
      [[ $local_branch == "master" ]] && local_branch_disp="m"
    # Abbreviate "master@origin" to "m@o" (common/normal).
    elif [[ $remote == "origin/master" ]] ; then
      remote=o/m
      [[ $local_branch == "master" ]] && local_branch_disp="m"
    elif [[ ${remote/\//-} == $local_branch ]]; then
      # username-branchname@username/branchname via `hub`.
      remote=✓
    else
      remote_color="%{$fg_bold[blue]%}"
    fi

    hook_com[branch]="${branch_color}${local_branch_disp}$remote_color@${remote}"
    [[ -n $gitstatus ]] && hook_com[branch]+="$bracket_open$normtext${(j:/:)gitstatus}$bracket_close"
    return 0
}

# Use xterm compatible escape codes for cursor shapes?
# Used in ~/.dotfiles/oh-my-zsh/themes/blueyed.zsh-theme / my-set-cursor-shape
# and Vim.
if is_urxvt || [[ -n $TMUX ]] || [[ $TERM == screen-256color ]] \
  || ([[ $TERM == xterm* ]] && [[ $COLORTERM != lilyterm ]] \
      && ! is_gnome_terminal); then
    export _USE_XTERM_CURSOR_CODES=1
else
    export _USE_XTERM_CURSOR_CODES=0
fi

_my_cursor_shape=auto
_auto-my-set-cursor-shape() {
    if [[ $_my_cursor_shape != "auto" ]]; then
        return
    fi
    my-set-cursor-shape "$@" auto
    _my_cursor_shape=auto
}
# Can be called manually, and will not be autoset then anymore.
# Not supported with gnome-terminal and "linux".
# $1: style; $2: "auto", when called automatically.
my-set-cursor-shape() {
    (( $+MC_SID )) && return  # Not for midnight commander.

    if [[ $1 == auto ]]; then
        _my_cursor_shape=auto
        echo "Using 'auto' again."
        return
    fi

    local code
    if [[ $_USE_XTERM_CURSOR_CODES == 1 ]]; then
        case "$1" in
            block_blink)     code='\e[1 q' ;;
            block)           code='\e[2 q' ;;
            underline_blink) code='\e[3 q' ;;
            underline)       code='\e[4 q' ;;
            bar_blink)       code='\e[5 q' ;;
            bar)             code='\e[6 q' ;;
            *) echo "my-set-cursor-shape: unknown arg: $1"; return 1 ;;
        esac
    elif (( $+KONSOLE_PROFILE_NAME )); then
        case "$1" in
            block_blink)     code='\e]50;CursorShape=0;BlinkingCursorEnabled=1\x7' ;;
            block)           code='\e]50;CursorShape=0;BlinkingCursorEnabled=0\x7' ;;
            underline_blink) code='\e]50;CursorShape=2;BlinkingCursorEnabled=1\x7' ;;
            underline)       code='\e]50;CursorShape=2;BlinkingCursorEnabled=0\x7' ;;
            bar_blink)       code='\e]50;CursorShape=1;BlinkingCursorEnabled=1\x7' ;;
            bar)             code='\e]50;CursorShape=1;BlinkingCursorEnabled=0\x7' ;;
            *) echo "my-set-cursor-shape: unknown arg: $1"; return 1 ;;
        esac
    else
        if [[ $2 != auto ]]; then
            echo "Terminal is not supported." >&2
        fi
        return
    fi

    if [[ -n $code ]]; then
        printf $code
    fi
    if [[ $2 != auto ]]; then
        _my_cursor_shape=$1
    fi
}
compdef -e '_arguments "1: :(block_blink block underline_blink underline bar_blink bar auto)"' my-set-cursor-shape

# Vim mode indicator {{{1
_zsh_vim_mode_indicator () {
    if (( $_USE_XTERM_CURSOR_CODES )) || (( $+KONSOLE_PROFILE_NAME )); then
        if [ $KEYMAP = vicmd ]; then
            _auto-my-set-cursor-shape block_blink
        else
            _auto-my-set-cursor-shape bar_blink
        fi
    elif [[ $TERM == xterm* ]]; then
        if [ $KEYMAP = vicmd ]; then
            # First set a color name (recognized by gnome-terminal), then the number from the palette (recognized by urxvt).
            # NOTE: not for "linux" or tmux on linux.
            printf "\033]12;#0087ff\007"
            printf "\033]12;4\007"
        else
            printf "\033]12;#5f8700\007"
            printf "\033]12;2\007"
        fi
    else
        # Dumb terminal, e.g. linux or screen/tmux in linux console.
        # If mode indicator wasn't setup by theme, define default.
        if [[ "$MODE_INDICATOR" == "" ]]; then
            MODE_INDICATOR="%{$fg_bold[red]%}<%{$fg_no_bold[red]%}<<%{$reset_color%}"
        fi

        export _ZSH_KEYMAP_INDICATOR="${${KEYMAP/vicmd/$MODE_INDICATOR}/(main|viins)/}"
        my-reset-prompt
    fi
}
eval "zle-keymap-select () { $functions[_zsh_vim_mode_indicator]; $functions[zle-keymap-select]; }"
eval "zle-line-init     () { $functions[_zsh_vim_mode_indicator]; $functions[zle-line-init]; }"
zle -N zle-keymap-select
zle -N zle-line-init
# Init.
_auto-my-set-cursor-shape block_blink

# Manage my_confirm_client_kill X client property (used by awesome). {{{
function get_x_focused_win_id() {
    set localoptions pipefail
    xprop -root 2>/dev/null | sed -n '/^_NET_ACTIVE_WINDOW/ s/.* // p'
}

if [[ -z $SSH_CLIENT ]] && is_urxvt && [[ -n $DISPLAY ]] &&
    [[ -n $WINDOWID ]] && [[ -z $TMUX ]]; then
    zmodload zsh/datetime  # for $EPOCHSECONDS

    _zsh_initial_display=$DISPLAY

    function set_my_confirm_client_kill() {
      # xprop -id $(get_x_focused_win_id) -f my_confirm_client_kill 8c
      xprop -display $_zsh_initial_display -id $WINDOWID -f my_confirm_client_kill 32c \
          -set my_confirm_client_kill $1 &!
    }
    function prompt_blueyed_confirmkill_preexec() {
      set_my_confirm_client_kill 1
    }
    function prompt_blueyed_confirmkill_precmd() {
      set_my_confirm_client_kill $EPOCHSECONDS
    }
    add-zsh-hook preexec prompt_blueyed_confirmkill_preexec
    add-zsh-hook precmd  prompt_blueyed_confirmkill_precmd
fi
# }}}

# Set block cursor before executing a program.
add-zsh-hook preexec prompt_blueyed_cursorstyle_preexec
function prompt_blueyed_cursorstyle_preexec() {
  _auto-my-set-cursor-shape block_blink
}
# }}}


# zstat_mime helper, conditionally defined.
# Load zstat module, but only its builtin `zstat`.
if ! zmodload -F zsh/stat b:zstat 2>/dev/null; then
  # If the module is not available, define a wrapper around `stat`, and use its
  # terse output instead of format, which is not supported by busybox.
  # Assume '+mtime' as $1.
  zstat_mtime() {
    stat -t $1 2>/dev/null | cut -f13 -d ' '
  }
else
  zstat_mtime() {
    zstat +mtime $1 2>/dev/null
  }
fi


### Run vcs_info selectively to increase speed. {{{
# Based on ~/Vcs/zsh/Misc/vcs_info-examples.
# zstyle ':vcs_info:*' check-for-changes true
# zstyle ':vcs_info:*' get-revision true

# Init gets done through _force_vcs_info_chpwd.
_ZSH_VCS_INFO_CUR_GITDIR=
_ZSH_VCS_INFO_CUR_VCS=
_ZSH_VCS_INFO_FORCE_GETDATA=
_ZSH_VCS_INFO_DIR_CHANGED=
_ZSH_VCS_INFO_LAST_MTIME=

zstyle ':vcs_info:*+start-up:*' hooks start-up
+vi-start-up() {
    ret=1  # do not run by default.

    if [[ -n $_ZSH_VCS_INFO_FORCE_GETDATA ]]; then
        _ZSH_VCS_INFO_LAST_MTIME=
        ret=0

    elif [[ -n $_ZSH_VCS_INFO_DIR_CHANGED ]]; then
        ret=0

    elif [[ $_ZSH_VCS_INFO_CUR_VCS == git ]]; then
        # Check mtime of .git dir.
        # If it changed force refresh of vcs_info data.
        local gitdir mtime

        gitdir=$_ZSH_VCS_INFO_CUR_GITDIR
        mtime=$(zstat_mtime $gitdir)
        if [[ $_ZSH_VCS_INFO_LAST_MTIME != $mtime ]]; then
            _ZSH_VCS_INFO_FORCE_GETDATA=1
            _ZSH_VCS_INFO_LAST_MTIME=$mtime
            _zsh_prompt_vcs_info+=("%{${fg[cyan]}%}⟳(m)")
            ret=0
        fi
    fi
}

# Hook for when no VCS was detected: cleanup vars.
zstyle ':vcs_info:*+no-vcs:*' hooks no-vcs
+vi-no-vcs() {
    _ZSH_VCS_INFO_CUR_GITDIR=
    _ZSH_VCS_INFO_CUR_VCS=
}

zstyle ':vcs_info:*+pre-get-data:*' hooks pre-get-data
+vi-pre-get-data() {
    _ZSH_VCS_INFO_CUR_VCS=$vcs  # for start-up hook.

    # Only Git and Mercurial support and need caching. Abort if any other
    # VCS is used.
    [[ "$vcs" != git && "$vcs" != hg ]] && return

    if [[ -n $_ZSH_VCS_INFO_DIR_CHANGED ]]; then
        _ZSH_VCS_INFO_DIR_CHANGED=
        if [[ $vcs == git ]]; then
            local gitdir=${${vcs_comm[gitdir]}:a}
            if [[ $gitdir != $_ZSH_VCS_INFO_CUR_GITDIR ]]; then
                _ZSH_VCS_INFO_FORCE_GETDATA=1
                _ZSH_VCS_INFO_CUR_GITDIR=$gitdir
                _ZSH_VCS_INFO_LAST_MTIME=
                _zsh_prompt_vcs_info+=("%{${fg[cyan]}%}⟳(cd)")
            fi
        else
            # Changed to some non-git dir.
            _ZSH_VCS_INFO_FORCE_GETDATA=1
            _ZSH_VCS_INFO_CUR_GITDIR=
            _zsh_prompt_vcs_info+=("%{${fg[cyan]}%}⟳(cd2)")
        fi
    fi

    if [[ $vcs == git && -z $_ZSH_VCS_INFO_LAST_MTIME ]]; then
        local gitdir=${${vcs_comm[gitdir]}:a}
        _ZSH_VCS_INFO_LAST_MTIME=$(zstat_mtime $gitdir)
    fi

    ret=1  # Do not run by default.
    if [[ -n $_ZSH_VCS_INFO_FORCE_GETDATA ]]; then
        _ZSH_VCS_INFO_FORCE_GETDATA=
        ret=0  # Refresh.
    fi
}

# Register directory changes: vcs_info must be run then usually.
# This is (later) optimized for git, where it's only triggered if the gitdir
# changed.
_force_vcs_info_chpwd() {
    # Force refresh with "cd .".
    if [[ $PWD == $_ZSH_VCS_INFO_PREV_PWD ]]; then
        _ZSH_VCS_INFO_FORCE_GETDATA=1
        _zsh_prompt_vcs_info+=("%{${fg[cyan]}%}⟳(f)")
    fi
    _ZSH_VCS_INFO_PREV_PWD=$PWD
    _ZSH_VCS_INFO_DIR_CHANGED=1
}
add-zsh-hook chpwd _force_vcs_info_chpwd
_force_vcs_info_chpwd  # init.

# Force vcs_info when the expanded, full command contains relevant strings.
# This also handles resumed jobs (via `fg`), based on code from termsupport.zsh.
_force_vcs_info_preexec() {
    _zsh_prompt_vcs_info=()
    (( $_ZSH_VCS_INFO_FORCE_GETDATA )) && return

    if _user_execed_command $1 $2 $3 '(git|hg|bcompare|nvim|vim)'; then
        _zsh_prompt_vcs_info+=("%{${fg[cyan]}%}⟳(c)")
        _ZSH_VCS_INFO_FORCE_GETDATA=1
    fi
}
add-zsh-hook preexec _force_vcs_info_preexec
# }}}

# Look for $4 (in "word boundaries") in preexec arguments ($1, $2, $3).
# $3 is the resolved command.
# Returns 0 if the command has (probably) been called, 1 otherwise.
_user_execed_command() {
    local lookfor="(*[[:space:]])#$4([[:space:]-]*)#"
    local ret=1
    if [[ $3 == ${~lookfor} ]]; then
        ret=0
    else
        local -a cmd
        if (( $#_zsh_resolved_jobspec )); then
            cmd=(${(z)_zsh_resolved_jobspec})
        else
            cmd=(${(z)3})
        fi
        # Look into function definitions, max. 50 lines.
        if (( $+functions[$cmd[1]] )); then
            if [[ ${${(f)"$(whence -f ${cmd[1]})"}[1,50]} == ${~lookfor} ]] ; then
                ret=0
            fi
        else
            # Allowing the command to be quoted.
            # E.g. with `gcm`: noglob _nomatch command_with_files "git commit --amend -m"
            local lookfor_quoted="(*[[:space:]=])#(|[\"\'\(])$4([[:space:]-]*)#"
            if [[ $(whence -f ${cmd[1]}) == ${~lookfor_quoted} ]] ; then
                ret=0
            fi
        fi
    fi
    return $ret
}


# Maintain cache for pyenv_version.
# It gets reset automatically when changing directories.
_pyenv_version_preexec() {
    if _user_execed_command $1 $2 $3 'pyenv'; then
        unset '_zsh_cache_pwd[pyenv_version]'
    fi
}
add-zsh-hook preexec _pyenv_version_preexec


color_for_host() {
    # FYI: list of colors: cyan, white, yellow, magenta, black, blue, red, default, grey, green
    colors=(cyan yellow magenta blue green)

    # NOTE: do not use `hostname -f`, which is slow with wacky network
    # %M resolves to the full hostname
    echo $(hash_value_from_list ${(%):-%M} "$colors")
}

# Hash the given value to an item from the given list.
# Note: if strange errors happen here, it is because of some DEBUG echo in ~/.zshenv/zshrc probably.
hash_value_from_list() {
    if ! (( ${+functions[(r)sumcharvals]} )); then
      source =sumcharvals
    fi

    value=$1
    list=(${(s: :)2})
    index=$(( $(sumcharvals $value) % $#list + 1 ))
    echo $list[$index]
}

# vcs_info styling formats {{{1
# XXX: %b is the whole path for CVS, see ~/src/b2evo/b2evolution/blogs/plugins
# NOTE: %b gets colored via hook_com.
FMT_BRANCH="%s:%{$fg_no_bold[blue]%}%b%{$fg_bold[blue]%}%{$fg_bold[magenta]%}%u%c" # e.g. master¹²
# FMT_BRANCH=" %{$fg_no_bold[blue]%}%s:%b%{$fg_bold[blue]%}%{$fg_bold[magenta]%}%u%c" # e.g. master¹²
FMT_ACTION="%{$fg_no_bold[cyan]%}(%a%)"   # e.g. (rebase-i)

# zstyle ':vcs_info:*+*:*' debug true
zstyle ':vcs_info:*:prompt:*' get-revision true # for %8.8i
zstyle ':vcs_info:*:prompt:*' unstagedstr '¹'  # display ¹ if there are unstaged changes
zstyle ':vcs_info:*:prompt:*' stagedstr '²'    # display ² if there are staged changes
zstyle ':vcs_info:*:prompt:*' actionformats "${FMT_BRANCH} ${FMT_ACTION}" "%m" "%R" "%.7i"
zstyle ':vcs_info:*:prompt:*' formats       "${FMT_BRANCH}"               "%m" "%R" "%.7i"
zstyle ':vcs_info:*:prompt:*' nvcsformats   ""                            ""   ""   ""
zstyle ':vcs_info:*:prompt:*' max-exports 4
# patch-format for Git, used during rebase.
zstyle ':vcs_info:git*:prompt:*' patch-format "%{$fg_no_bold[cyan]%}Patch: %p [%n/%a]"


# vim: set ft=zsh ts=4 sw=4 et:
