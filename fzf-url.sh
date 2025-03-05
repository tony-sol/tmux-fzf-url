#!/usr/bin/env bash
#===============================================================================
#   Author: Wenxuan
#    Email: wenxuangm@gmail.com
#  Created: 2018-04-06 12:12
#===============================================================================
get_fzf_with_options() {
    local fzf_bin
    local fzf_default_options
    # @see https://junegunn.github.io/fzf/releases/0.53.0/#native-tmux-integration
    local fzf_desired_version='0.53.0'
    local fzf_actual_version=$(fzf --version | awk '{print $1}')zf_actual_version=$(fzf --version | awk '{print $1}')
    if [ "$fzf_desired_version" = $(echo -e "$fzf_desired_version\n$fzf_actual_version" | sort -V | head -n1) ]; then
        fzf_bin='fzf'
        fzf_default_options='--tmux center,100%,50% --multi --exit-0 --no-preview'
    else
        fzf_bin='fzf-tmux'
        fzf_default_options='-w 100% -h 50% --multi -0 --no-preview'
    fi

    local fzf_options
    fzf_options="$(tmux show -gqv '@fzf-url-fzf-options')"
    echo "$fzf_bin $([ -n "$fzf_options" ] && echo "$fzf_options" || echo "$fzf_default_options")"
}

fzf_filter() {
    eval "$(get_fzf_with_options)"
}

custom_open=$3
open_url() {
    if [[ -n $custom_open ]]; then
        $custom_open "$@"
    elif hash xdg-open &>/dev/null; then
        nohup xdg-open "$@"
    elif hash open &>/dev/null; then
        nohup open "$@"
    elif [[ -n $BROWSER ]]; then
        nohup "$BROWSER" "$@"
    fi
}

limit='screen'
[[ $# -ge 2 ]] && limit=$2

if [[ $limit == 'screen' ]]; then
    content="$(tmux capture-pane -J -p -e |sed -r 's/\x1B\[[0-9;]*[mK]//g'))"
else
    content="$(tmux capture-pane -J -p -e -S -"$limit" |sed -r 's/\x1B\[[0-9;]*[mK]//g'))"
fi

urls=$(echo "$content" |grep -oE '(https?|ftp|file):/?//[-A-Za-z0-9+&@#/%?=~_|!:,.;]*[-A-Za-z0-9+&@#/%=~_|]')
wwws=$(echo "$content" |grep -oE '(http?s://)?www\.[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}(/\S+)*' | grep -vE '^https?://' |sed 's/^\(.*\)$/http:\/\/\1/')
ips=$(echo "$content" |grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]{1,5})?(/\S+)*' |sed 's/^\(.*\)$/http:\/\/\1/')
gits=$(echo "$content" |grep -oE '(ssh://)?git@\S*' | sed 's/:/\//g' | sed 's/^\(ssh\/\/\/\)\{0,1\}git@\(.*\)$/https:\/\/\2/')
gh=$(echo "$content" |grep -oE "['\"]([_A-Za-z0-9-]*/[_.A-Za-z0-9-]*)['\"]" | sed "s/['\"]//g" | sed 's#.#https://github.com/&#')

if [[ $# -ge 1 && "$1" != '' ]]; then
    extras=$(echo "$content" |eval "$1")
fi

items=$(printf '%s\n' "${urls[@]}" "${wwws[@]}" "${gh[@]}" "${ips[@]}" "${gits[@]}" "${extras[@]}" |
    grep -v '^$' |
    sort -u |
    nl -w3 -s '  '
)
[ -z "$items" ] && tmux display 'tmux-fzf-url: no URLs found' && exit

fzf_filter <<< "$items" | awk '{print $2}' | \
    while read -r chosen; do
        open_url "$chosen" &>"/tmp/tmux-$(id -u)-fzf-url.log"
    done
