#!/usr/bin/env bash

POWERLINE_ORG_PS1=$PS1

alias prompt_short_dir="export POWERLINE_SHORT=dir"
alias prompt_short_path="export POWERLINE_SHORT=path"
alias prompt_short_off="export POWERLINE_SHORT=off"

alias prompt_reload="source ~/.bashrc"
alias prompt_default="export PROMPT_COMMAND=ps1_default"
alias prompt_off="export PROMPT_COMMAND=ps1_off"
alias prompt_on="export PROMPT_COMMAND=ps1_on"

__powerline() {

    # unicode symbols
    ICONS=( "⚑" "»" "♆" "☀" "♞" "☯" "☢" "❄" )
    ARROWS=( "⇠" "⇡" "⇢" "⇣" )
    PS_SYMBOL_USER='$'
    PS_SYMBOL_ROOT='#'
    GIT_BRANCH_SYMBOL=${ICONS[1]}
    GIT_BRANCH_CHANGED_SYMBOL='+'
    GIT_NEED_PUSH_SYMBOL=${ARROWS[1]}
    GIT_NEED_PULL_SYMBOL=${ARROWS[3]}

    # color specials
    DIM="\[$(tput dim)\]"
    REVERSE="\[$(tput rev)\]"
    RESET="\[$(tput sgr0)\]"
    BOLD="\[$(tput bold)\]"

    # color definitions
    COLOR_USER="\[$(tput setaf 15)\]\[$(tput setab 8)\]"
    COLOR_SUDO="\[$(tput setaf 3)\]\[$(tput setab 8)\]"
    COLOR_SSH="\[$(tput setaf 3)\]\[$(tput setab 8)\]"
    COLOR_DIR="\[$(tput setaf 7)\]\[$(tput setab 8)\]"
    COLOR_GIT="\[$(tput setaf 15)\]\[$(tput setab 4)\]"
    COLOR_RC="\[$(tput setaf 15)\]\[$(tput setab 9)\]"
    COLOR_JOBS="\[$(tput setaf 15)\]\[$(tput setab 5)\]"
    COLOR_PS_USER="\[$(tput setaf 15)\]\[$(tput setab 2)\]"
    COLOR_PS_ROOT="\[$(tput setaf 15)\]\[$(tput setab 1)\]"

    # solarized colorscheme
    #FG_BASE03="\[$(tput setaf 8)\]"
    #FG_BASE02="\[$(tput setaf 0)\]"
    #FG_BASE01="\[$(tput setaf 10)\]"
    #FG_BASE00="\[$(tput setaf 11)\]"
    #FG_BASE0="\[$(tput setaf 12)\]"
    #FG_BASE1="\[$(tput setaf 14)\]"
    #FG_BASE2="\[$(tput setaf 7)\]"
    #FG_BASE3="\[$(tput setaf 15)\]"

    #BG_BASE03="\[$(tput setab 8)\]"
    #BG_BASE02="\[$(tput setab 0)\]"
    #BG_BASE01="\[$(tput setab 10)\]"
    #BG_BASE00="\[$(tput setab 11)\]"
    #BG_BASE0="\[$(tput setab 12)\]"
    #BG_BASE1="\[$(tput setab 14)\]"
    #BG_BASE2="\[$(tput setab 7)\]"
    #BG_BASE3="\[$(tput setab 15)\]"

    #FG_YELLOW="\[$(tput setaf 3)\]"
    #FG_ORANGE="\[$(tput setaf 9)\]"
    #FG_RED="\[$(tput setaf 1)\]"
    #FG_MAGENTA="\[$(tput setaf 5)\]"
    #FG_VIOLET="\[$(tput setaf 13)\]"
    #FG_BLUE="\[$(tput setaf 4)\]"
    #FG_CYAN="\[$(tput setaf 6)\]"
    #FG_GREEN="\[$(tput setaf 2)\]"

    #BG_YELLOW="\[$(tput setab 3)\]"
    #BG_ORANGE="\[$(tput setab 9)\]"
    #BG_RED="\[$(tput setab 1)\]"
    #BG_MAGENTA="\[$(tput setab 5)\]"
    #BG_VIOLET="\[$(tput setab 13)\]"
    #BG_BLUE="\[$(tput setab 4)\]"
    #BG_CYAN="\[$(tput setab 6)\]"
    #BG_GREEN="\[$(tput setab 2)\]"

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
        local aheadN="$(echo $stat | grep -o 'ahead [0-9]*' | grep -o '[0-9]')"
        local behindN="$(echo $stat | grep -o 'behind [0-9]*' | grep -o '[0-9]')"
        [ -n "$aheadN" ] && marks+=" $GIT_NEED_PUSH_SYMBOL$aheadN"
        [ -n "$behindN" ] && marks+=" $GIT_NEED_PULL_SYMBOL$behindN"

        # print the git branch segment without a trailing newline
        printf "$COLOR_GIT $GIT_BRANCH_SYMBOL$branch$marks $RESET"
    }

    __user_display() {
        # check if running sudo
        if [ -z "$SUDO_USER" ]; then
            local IS_SUDO=""
        else
            local IS_SUDO="$COLOR_SUDO"
        fi

        # check if ssh session
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
            local IS_SSH="$COLOR_SSH@$HOSTNAME"
        else
            local IS_SSH=""
        fi
        printf "$COLOR_USER$IS_SUDO $USER$IS_SSH $RESET"
    }

    __short_dir() {
        local DIR_SPLIT_COUNT=4
        IFS='/' read -a DIR_ARRAY <<< "$PWD"
        if [ ${#DIR_ARRAY[@]} -gt $DIR_SPLIT_COUNT ]; then
            local SHORT_DIR="/${DIR_ARRAY[1]}/.../${DIR_ARRAY[${#DIR_ARRAY[@]}-2]}/${DIR_ARRAY[${#DIR_ARRAY[@]}-1]}"
        else
            local SHORT_DIR="$PWD"
        fi
        if [ "$HOME" == "$PWD" ]; then
            local SHORT_DIR="~"
        fi
        printf "$SHORT_DIR"
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
        printf "$SHORT_PATH"
   }

   __dir_display() {
        if [ "$POWERLINE_SHORT" == "dir" ]; then
          local DIR_DISPLAY=$(__short_dir)
        elif [ "$POWERLINE_SHORT" == "path" ]; then
          local DIR_DISPLAY=$(__short_path)
        elif [ "$POWERLINE_SHORT" == "off" ]; then
          local DIR_DISPLAY=$PWD
        else
          local DIR_DISPLAY=$(__short_dir)
        fi
        printf "$COLOR_DIR $DIR_DISPLAY $RESET"
   }

   __jobs_display() {
        if [ "$(jobs | wc -l)" -ne "0" ]; then
            local JOBS_DISPLAY="$COLOR_JOBS $(jobs | wc -l) $RESET"
        else
            local JOBS_DISPLAY=""
        fi
        printf "$JOBS_DISPLAY"
   }

   __ps_display() {
        # check if root or regular user
        if [ $EUID -ne 0 ]; then
            local PS_SYMBOL_BG=$COLOR_PS_USER
            local PS_SYMBOL=$PS_SYMBOL_USER
        else
            local PS_SYMBOL_BG=$COLOR_PS_ROOT
            local PS_SYMBOL=$PS_SYMBOL_ROOT
        fi
        printf "$PS_SYMBOL_BG $PS_SYMBOL $RESET"
   }

   __rc_display() {
        # check the exit code of the previous command and display different
        local rc=$1
        if [ $rc -ne 0 ]; then
            local RC_DISPLAY="$COLOR_RC $rc $RESET"
        else
            local RC_DISPLAY=""
        fi
        printf "$RC_DISPLAY"
   }

    ps1_default() {
        # set prompt
        PS1=$POWERLINE_ORG_PS1 
    }

    ps1_off() {
        # set prompt
        PS1="$ "
    }

    ps1_on() {
        # capture latest return code
        local RETURN_CODE=$?

        # set prompt
        PS1=""
        PS1+="$(__user_display)"
        PS1+="$(__dir_display)"
        PS1+="$(__git_info)"
        PS1+="$(__jobs_display)"
        PS1+="$(__ps_display)"
        PS1+="$(__rc_display ${RETURN_CODE})"
        PS1+=" "
    }

    PROMPT_COMMAND=ps1_on
}

__powerline
unset __powerline
