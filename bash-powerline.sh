#!/usr/bin/env bash

alias prompt_short_dir="export POWERLINE_SHORT=dir"
alias prompt_short_path="export POWERLINE_SHORT=path"
alias prompt_short_default="export POWERLINE_SHORT=default"
alias prompt_short_off="export POWERLINE_SHORT=default"

alias prompt_reload="source ~/.bashrc"

__powerline() {

    # Unicode symbols
    PS_SYMBOL_USER='$'
    PS_SYMBOL_ROOT='#'
    GIT_BRANCH_SYMBOL='»'
    GIT_BRANCH_CHANGED_SYMBOL='+'
    GIT_NEED_PUSH_SYMBOL='⇡'
    GIT_NEED_PULL_SYMBOL='⇣'

    # Solarized colorscheme
    FG_BASE03="\[$(tput setaf 8)\]"
    FG_BASE02="\[$(tput setaf 0)\]"
    FG_BASE01="\[$(tput setaf 10)\]"
    FG_BASE00="\[$(tput setaf 11)\]"
    FG_BASE0="\[$(tput setaf 12)\]"
    FG_BASE1="\[$(tput setaf 14)\]"
    FG_BASE2="\[$(tput setaf 7)\]"
    FG_BASE3="\[$(tput setaf 15)\]"

    BG_BASE03="\[$(tput setab 8)\]"
    BG_BASE02="\[$(tput setab 0)\]"
    BG_BASE01="\[$(tput setab 10)\]"
    BG_BASE00="\[$(tput setab 11)\]"
    BG_BASE0="\[$(tput setab 12)\]"
    BG_BASE1="\[$(tput setab 14)\]"
    BG_BASE2="\[$(tput setab 7)\]"
    BG_BASE3="\[$(tput setab 15)\]"

    FG_YELLOW="\[$(tput setaf 3)\]"
    FG_ORANGE="\[$(tput setaf 9)\]"
    FG_RED="\[$(tput setaf 1)\]"
    FG_MAGENTA="\[$(tput setaf 5)\]"
    FG_VIOLET="\[$(tput setaf 13)\]"
    FG_BLUE="\[$(tput setaf 4)\]"
    FG_CYAN="\[$(tput setaf 6)\]"
    FG_GREEN="\[$(tput setaf 2)\]"

    BG_YELLOW="\[$(tput setab 3)\]"
    BG_ORANGE="\[$(tput setab 9)\]"
    BG_RED="\[$(tput setab 1)\]"
    BG_MAGENTA="\[$(tput setab 5)\]"
    BG_VIOLET="\[$(tput setab 13)\]"
    BG_BLUE="\[$(tput setab 4)\]"
    BG_CYAN="\[$(tput setab 6)\]"
    BG_GREEN="\[$(tput setab 2)\]"

    DIM="\[$(tput dim)\]"
    REVERSE="\[$(tput rev)\]"
    RESET="\[$(tput sgr0)\]"
    BOLD="\[$(tput bold)\]"

    __git_info() { 
        [ -x "$(which git)" ] || return    # git not found

        # get current branch name or short SHA1 hash for detached head
        local branch="$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)"
        [ -n "$branch" ] || return  # git branch not found

        local marks

        # branch is modified?
        [ -n "$(git status --porcelain)" ] && marks+=" $GIT_BRANCH_CHANGED_SYMBOL"

        # how many commits local branch is ahead/behind of remote?
        local stat="$(git status --porcelain --branch | head -n1)"
        local aheadN="$(echo $stat | grep  'ahead' | grep -o '[0-9]')"
        local behindN="$(echo $stat | grep 'behind' | grep -o '[0-9]')"
        [ -n "$aheadN" ] && marks+=" $GIT_NEED_PUSH_SYMBOL$aheadN"
        [ -n "$behindN" ] && marks+=" $GIT_NEED_PULL_SYMBOL$behindN"

        # print the git branch segment without a trailing newline
        printf " $GIT_BRANCH_SYMBOL$branch$marks "
    }

    __short_dir() {
        local DIR_SPLIT_COUNT=4
        IFS='/' read -a DIR_ARRAY <<< "$PWD"
        if [ ${#DIR_ARRAY[@]} -gt $DIR_SPLIT_COUNT ]; then
            local DIR_OUTPUT="/${DIR_ARRAY[1]}/.../${DIR_ARRAY[${#DIR_ARRAY[@]}-2]}/${DIR_ARRAY[${#DIR_ARRAY[@]}-1]}"
        else
            local DIR_OUTPUT="$PWD"
        fi
        if [ "$HOME" == "$PWD" ]; then
            local DIR_OUTPUT="~"
        fi
        printf "$DIR_OUTPUT"
    }

    __short_path() {
        local SHORT_NUM=20
        if (( ${#PWD} > $SHORT_NUM )); then
            local SHORT_PATH="..${PWD: -$SHORT_NUM}"
        else
            local SHORT_PATH=$PWD
        fi
        if [ "$HOME" == "$PWD" ]; then
            local SHORT_PATH="~"
        fi
        echo $SHORT_PATH
   }

    ps1() {
        # Check the exit code of the previous command and display different
        # colors in the prompt accordingly. 
        local rc=$?
        if [ $rc -ne 0 ]; then
            local BG_EXIT="$BG_ORANGE$FG_BASE3 $rc $RESET"
        else
            local BG_EXIT=""
        fi
        # Check if root or regular user
        if [ $EUID -ne 0 ]; then
            local BG_ROOT="$BG_GREEN"
            local PS_SYMBOL=$PS_SYMBOL_USER
        else
            local BG_ROOT="$BG_RED"
            local PS_SYMBOL=$PS_SYMBOL_ROOT
        fi

        # Check if running sudo
        if [ -z "$SUDO_USER" ]; then
            local IS_SUDO=""
        else
            local IS_SUDO="$FG_YELLOW"
        fi

        # Check if ssh session
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
            local IS_SSH="$BG_BASE03$FG_YELLOW@\h"
        else
            local IS_SSH=""
        fi

        # Check short method
        if [ "$POWERLINE_SHORT" == "dir" ]; then
          local SHORT=$(__short_dir)
        elif [ "$POWERLINE_SHORT" == "path" ]; then
          local SHORT=$(__short_path)
        elif [ "$POWERLINE_SHORT" == "default" ]; then
          local SHORT=$PWD
        else
          local SHORT=$(__short_dir)
        fi

        PS1=""
        PS1+="$BG_BASE03$FG_BASE3$IS_SUDO \u$IS_SSH $RESET"
        PS1+="$BG_BASE03$FG_BASE3 $SHORT $RESET"
        PS1+="$BG_BLUE$FG_BASE3$(__git_info)$RESET"
        PS1+="$BG_ROOT$FG_BASE3 $PS_SYMBOL $RESET"
        PS1+="$BG_EXIT"
        PS1+=" "
    }

    PROMPT_COMMAND=ps1
}

__powerline
unset __powerline
