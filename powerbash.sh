#!/usr/bin/env bash

# exit for non-interactive
[[ -z $PS1 ]] && return

powerbash() {
  case "$1" in
    reload) source ~/.bashrc ;;
    prompt)
      case "$2" in
        on|off|system) export PROMPT_COMMAND="__powerbash_ps1 $2" ;;
        *) echo "invalid option" ;;
      esac
    ;;
    config)
      case "$2" in
        default|load|save) __powerbash_config $2 ;;
        *) echo "invalid option" ;;
      esac
    ;;
    py)
      case "$2" in
        virtualenv)
          case "$3" in
            on|off|auto) export "POWERBASH_${1^^}_${2^^}"="$3" ;;
          esac
          ;;
        *) echo "invalid option" ;;
      esac
    ;;
    user|git|jobs|symbol|rc)
      case "$2" in
        on|off) export "POWERBASH_${1^^}"="$2" ;;
        *) echo "invalid option" ;;
      esac
    ;;
    host)
      case "$2" in
        on|off|auto) export "POWERBASH_${1^^}"="$2" ;;
        *) echo "invalid option" ;;
      esac
    ;;
    path)
      case "$2" in
        off|full|working|parted|mini) export "POWERBASH_${1^^}"="$2" ;;
        short)
          export "POWERBASH_${1^^}"="$2"
          case "$3" in
            add|subtract) __powerbash_path_short_length $3 $4 ;;
          esac
          ;;
        *) echo "invalid option" ;;
      esac
    ;;
    term)
      case "$2" in
        xterm|xterm-256color|screen|screen-256color) export "TERM"="$2" ;;
        *) echo "invalid option" ;;
      esac
    ;;
    *) echo "invalid option" ;;
  esac
}

__powerbash_complete() {
  local cur prev option_list
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [ $COMP_CWORD -eq 1 ]; then
    # first level options
    option_list="reload prompt config py user host path git jobs symbol rc term"
  elif [ $COMP_CWORD -eq 2 ]; then
    # second level options
    case "${prev}" in
      prompt) option_list="on off system" ;;
      config) option_list="default load save" ;;
          py) option_list="virtualenv" ;;
        user) option_list="on off" ;;
        host) option_list="on off auto" ;;
        path) option_list="off full working short parted mini" ;;
         git) option_list="on off" ;;
        jobs) option_list="on off" ;;
      symbol) option_list="on off" ;;
          rc) option_list="on off" ;;
        term) option_list="xterm xterm-256color screen screen-256color" ;;
    esac
  elif [ $COMP_CWORD -eq 3 ]; then
    # third level options
    case "${prev}" in
      virtualenv) option_list="on off auto" ;;
      short) option_list="add subtract" ;;
    esac
  fi
  COMPREPLY=( $(compgen -W "${option_list}" -- ${cur}) )
}

__powerbash() {
  # define variables
  POWERBASH_ICONS=( "⚑" "»" "♆" "☀" "♞" "☯" "☢" "❄" "+" "▶" )
  POWERBASH_ARROWS=( "⇠" "⇡" "⇢" "⇣" )
  POWERBASH_PY_VIRTUALENV_SYMBOL=${POWERBASH_ICONS[9]}
  POWERBASH_GIT_BRANCH_SYMBOL=${POWERBASH_ICONS[1]}
  POWERBASH_GIT_BRANCH_CHANGED_SYMBOL=${POWERBASH_ICONS[8]}
  POWERBASH_GIT_NEED_PUSH_SYMBOL=${POWERBASH_ARROWS[1]}
  POWERBASH_GIT_NEED_PULL_SYMBOL=${POWERBASH_ARROWS[3]}
  DIM="\[$(tput dim)\]"
  REVERSE="\[$(tput rev)\]"
  RESET="\[$(tput sgr0)\]"
  BOLD="\[$(tput bold)\]"

  __powerbash_config() {
    case "$1" in
      default)
        [ -e "${POWERBASH_CONFIG}" ] && rm ${POWERBASH_CONFIG}
        while read -r param; do
          unset "${param}"
        done <<< "`env | grep \"POWERBASH_\" | sed \"s/=.*//g\"`"
        ;;
      load)
        if [ -e "${POWERBASH_CONFIG}" ]; then
          while read p; do
            export $p
          done < ${POWERBASH_CONFIG}
        fi
        ;;
      save)
        echo -n "" > ${POWERBASH_CONFIG}
        env | grep "POWERBASH_" >> ${POWERBASH_CONFIG}
        ;;
    esac
  }

  __powerbash_colors() {
    if (( $(tput colors) < 256 )); then
      # 8 color support
      COLOR_USER="\[$(tput setaf 7)\]\[$(tput setab 0)\]"
      COLOR_SUDO="\[$(tput setaf 3)\]\[$(tput setab 0)\]"
      COLOR_SSH="\[$(tput setaf 3)\]\[$(tput setab 0)\]"
      COLOR_DIR="\[$(tput setaf 7)\]\[$(tput setab 0)\]"
      COLOR_GIT="\[$(tput setaf 7)\]\[$(tput setab 4)\]"
      COLOR_RC="\[$(tput setaf 7)\]\[$(tput setab 1)\]"
      COLOR_JOBS="\[$(tput setaf 7)\]\[$(tput setab 5)\]"
      COLOR_SYMBOL_USER="\[$(tput setaf 7)\]\[$(tput setab 2)\]"
      COLOR_SYMBOL_ROOT="\[$(tput setaf 7)\]\[$(tput setab 1)\]"
    else
      # 256 color support
      COLOR_USER="\[$(tput setaf 15)\]\[$(tput setab 8)\]"
      COLOR_SUDO="\[$(tput setaf 3)\]\[$(tput setab 8)\]"
      COLOR_SSH="\[$(tput setaf 3)\]\[$(tput setab 8)\]"
      COLOR_DIR="\[$(tput setaf 7)\]\[$(tput setab 8)\]"
      COLOR_GIT="\[$(tput setaf 15)\]\[$(tput setab 4)\]"
      COLOR_RC="\[$(tput setaf 15)\]\[$(tput setab 9)\]"
      COLOR_JOBS="\[$(tput setaf 15)\]\[$(tput setab 5)\]"
      COLOR_PY_VIRTUALENV="\[$(tput setaf 15)\]\[$(tput setab 5)\]"
      COLOR_SYMBOL_USER="\[$(tput setaf 15)\]\[$(tput setab 2)\]"
      COLOR_SYMBOL_ROOT="\[$(tput setaf 15)\]\[$(tput setab 1)\]"
    fi
  }

  __powerbash_py_virtualenv_display() {
    [ -z "$POWERBASH_PY_VIRTUALENV" ] && POWERBASH_PY_VIRTUALENV="on" # sane default
    [ "$POWERBASH_PY_VIRTUALENV" == "off" ] && return # disable display
    [ -n "$VIRTUAL_ENV" ] || return # virtualenvironment not found

    # get virtualenv name
    local venv="$(basename $VIRTUAL_ENV)"
    [ -n "$venv" ] || return

    printf "$COLOR_PY_VIRTUALENV $POWERBASH_PY_VIRTUALENV_SYMBOL $venv $RESET"
  }

  __powerbash_git_display() {
    [ -z "$POWERBASH_GIT" ] && POWERBASH_GIT="on" # sane default
    [ "$POWERBASH_GIT" == "off" ] && return # disable display
    [ -x "$(which git)" ] || return # git not found

    # get current branch name or short SHA1 hash for detached head
    local branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)"
    [ -n "$branch" ] || return  # git branch not found

    local marks

    # branch is modified?
    [ -n "$(git status --porcelain)" ] && marks+=" $POWERBASH_GIT_BRANCH_CHANGED_SYMBOL"

    # how many commits local branch is ahead/behind of remote?
    local stat="$(git rev-list --left-right --boundary @{u}... 2>/dev/null)"
    local aheadN="$(echo $stat | grep -o ">" -c)"
    local behindN="$(echo $stat | grep -o "<" -c)"
    [ "$aheadN" -gt 0 ] && marks+=" $POWERBASH_GIT_NEED_PUSH_SYMBOL$aheadN"
    [ "$behindN" -gt 0 ] && marks+=" $POWERBASH_GIT_NEED_PULL_SYMBOL$behindN"

    printf "$COLOR_GIT $POWERBASH_GIT_BRANCH_SYMBOL$branch$marks $RESET"
  }

  __powerbash_user_display() {
    [ -z "$POWERBASH_USER" ] && POWERBASH_USER="on" # sane default
    [ "$POWERBASH_USER" == "off" ] && return # disable display
    [ -n "$SUDO_USER" ] && COLOR_USER="$COLOR_SUDO"
    [ "$POWERBASH_USER" == "on" ] && printf "$COLOR_USER \\\u $RESET"
  }

  __powerbash_host_display() {
    [ -z "$POWERBASH_HOST" ] && POWERBASH_HOST="auto" # sane default
    [ "$POWERBASH_HOST" == "off" ] && return # disable display
    [ "$POWERBASH_HOST" == "auto" ] && [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && POWERBASH_HOST=on
    [ "$POWERBASH_HOST" == "on" ] && printf "$COLOR_SSH@\\h $RESET"
  }

  __powerbash_path_parted() {
    local dir_split_count=4
    local dir_parted="$PWD"
    local dir_array=""

    IFS='/' read -a dir_array <<< "$PWD"
    if [ ${#dir_array[@]} -gt $dir_split_count ]; then
      local dir_parted="/${dir_array[1]}/.../${dir_array[${#dir_array[@]}-2]}/${dir_array[${#dir_array[@]}-1]}"
    fi

    printf "$dir_parted"
  }

  __powerbash_path_short() {
    [ -z "$POWERBASH_PATH_SHORT_LENGTH" ] && POWERBASH_PATH_SHORT_LENGTH=20 # sane default

    local short_path=$PWD
    (( ${#PWD} > $POWERBASH_PATH_SHORT_LENGTH )) && short_path="..${PWD: -$POWERBASH_PATH_SHORT_LENGTH}"

    printf "$short_path"
  }

  __powerbash_path_short_length() {
    [ -z "$POWERBASH_PATH_SHORT_LENGTH" ] && POWERBASH_PATH_SHORT_LENGTH=20 # sane default

    [ -n $2 ] && local length="$2" # add/subtract by $2 when provided
    [ -z "$length" ] && local length="1" # add/subtract by 1 by default
    [ "$1" == "subtract" ] && ((POWERBASH_PATH_SHORT_LENGTH-=$length))
    [ "$1" == "add" ] && ((POWERBASH_PATH_SHORT_LENGTH+=$length))

    return 0
  }

  __powerbash_path_mini() {
    local current_path="${PWD/$HOME/\~}"

    IFS='/' read -a dir_array <<< "$current_path"

    local path=""
    local dir_len=$((${#dir_array[@]}-1))

    for dir in ${dir_array[@]:0:$dir_len}; do
      [[ $dir == '~' ]] && path="${dir:0:1}" || path="$path/${dir:0:1}"
    done
    path="$path/${dir_array[$dir_len]}"

    printf "$path"
  }

  __powerbash_path_display() {
    [ -z "$POWERBASH_PATH" ] && POWERBASH_PATH="working" # sane default
    [ "$POWERBASH_PATH" == "off" ] && return # disable display
    [ "$PWD" == "$HOME" ] && POWERBASH_PATH="home" #display ~ for home

    local dir_display=""
    case "$POWERBASH_PATH" in
         home) dir_display="~" ;;
         full) dir_display="\\w" ;;
      working) dir_display="\\W" ;;
        short) dir_display="$(__powerbash_path_short)" ;;
       parted) dir_display="$(__powerbash_path_parted)" ;;
         mini) dir_display="$(__powerbash_path_mini)" ;;
    esac

    printf "$COLOR_DIR $dir_display $RESET"
  }

  __powerbash_jobs_display() {
    [ -z "$POWERBASH_JOBS" ] && POWERBASH_JOBS="on" # sane default
    [ "$POWERBASH_JOBS" == "off" ] && return # disable display
    [ $(jobs | wc -l) -ne "0" ] && printf "$COLOR_JOBS \\j $RESET"
  }

  __powerbash_symbol_display() {
    [ -z "$POWERBASH_SYMBOL" ] && POWERBASH_SYMBOL="on" # sane default
    [ "$POWERBASH_SYMBOL" == "off" ] && return # disable display

    # different color for root and regular user
    local symbol_bg=$COLOR_SYMBOL_USER
    [ $EUID -eq 0 ] && symbol_bg=$COLOR_SYMBOL_ROOT

    printf "$symbol_bg \\$ $RESET"
  }

  __powerbash_rc_display() {
    [ -z "$POWERBASH_RC" ] && POWERBASH_RC="on" # sane default
    [ "$POWERBASH_RC" == "off" ] && return # disable display
    [ $1 -ne 0 ] && printf "$COLOR_RC $1 $RESET"
  }

  __powerbash_ps1() {
    # keep this at top!!!
    # capture latest return code
    local RETURN_CODE=$?

    case "$1" in
      off)    PS1='\$ ' ;;
      system) PS1=$POWERBASH_SYSTEM_PS1 ;;
      on)
        # check for supported colors
        __powerbash_colors

        # set prompt
        PS1=""
        PS1+="$(__powerbash_py_virtualenv_display)"
        PS1+="$(__powerbash_user_display)"
        PS1+="$(__powerbash_host_display)"
        PS1+="$(__powerbash_path_display)"
        PS1+="$(__powerbash_git_display)"
        PS1+="$(__powerbash_jobs_display)"
        PS1+="$(__powerbash_symbol_display)"
        PS1+="$(__powerbash_rc_display ${RETURN_CODE})"
        PS1+=" "
        ;;
    esac
  }

  PROMPT_COMMAND="__powerbash_ps1 on"
}

# save system PS1
[[ -z "$POWERBASH_SYSTEM_PS1" ]] && POWERBASH_SYSTEM_PS1=$PS1

# start powerbash
__powerbash
unset __powerbash

# load saved configuration
POWERBASH_CONFIG="$HOME/.powerbash_config"
[[ -e "$POWERBASH_CONFIG" ]] && __powerbash_config load

# enable auto completion
complete -F __powerbash_complete powerbash
