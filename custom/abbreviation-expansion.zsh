# Source http://git.grml.org/?p=grml-etc-core.git;a=blob_plain;f=etc/zsh/zshrc;hb=HEAD

# power completion / abbreviation expansion / buffer expansion
# see http://zshwiki.org/home/examples/zleiab for details
# less risky than the global aliases but powerful as well
# just type the abbreviation key and afterwards 'ctrl-x .' to expand it
declare -A abk
abk=(
#   key   # value                  (#d additional doc string)
#A# start
    'BG'   '& exit'
    'C'    '| wc -l'
    'G'    '|& grep --color=auto '
    'H'    '| head'
    'Hl'   ' --help |& less -r'    #d (Display help in pager)
    'L'    '| less'
    'LL'   '|& less -r'
    'M'    '| most'
    'N'    '&>/dev/null'           #d (No Output)
    'R'    '| tr A-z N-za-m'       #d (ROT13)
    'SL'   '| sort | less'
    'S'    '| sort -u'
    'T'    '| tail'
    'V'    '|& vim -'
    'B'    '$(current_branch)'
#A# end
    'co'   './configure && make && sudo make install'
)

zleiab() {
    emulate -L zsh
    setopt extendedglob
    local MATCH

    if (( NOABBREVIATION > 0 )) ; then
        LBUFFER="${LBUFFER},."
        return 0
    fi

    LBUFFER=${LBUFFER%%(#m)[.\-+:|_a-zA-Z0-9]#}
    LBUFFER+=${abk[$MATCH]:-$MATCH}
}
zle -N zleiab


help-show-abk()
{
  zle -M "$(print "Type 'C-x .' after these abbreviations to expand them:"; print -a -C 2 ${(kv)abk})"
}
zle -N help-show-abk


bindkey '^x.' zleiab
bindkey '^xb' help-show-abk
