#!/usr/bin/env bash

# enable auto completion
complete -F __powerbash_complete powerbash

# save system PS1
[ -z "$POWERBASH_SYSTEM_PS1" ] && POWERBASH_SYSTEM_PS1=$PS1

powerbash() {
  case "$@" in
    @(on|off|system))
     export PROMPT_COMMAND="__powerbash_ps1 $1"
     ;;
    reload)
      source ~/.bashrc
      ;;
    @(user|host|path|git|jobs|symbol|rc)\ @(on|off|auto))
      export "POWERBASH_${1^^}"="$2"
      ;;
    path\ @(full|working-directory|short-directory|short-path|mini-dir))
      export "POWERBASH_${1^^}"="$2"
      ;;
    path\ short-path\ @(add|subtract))
      __powerbash_short_num_change $3 $4
      ;;
    config*)
      __powerbash_config $2
      ;;
    term*)
      export "TERM"="$2"
      ;;
    *)
      echo "invalid option"
  esac
}

__powerbash_complete() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="on off system reload path user host jobs git symbol rc term config"

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  elif [ $COMP_CWORD -ge 2 ]; then
    case "${prev}" in
      @(user|jobs|git|symbol|rc))
        COMPREPLY=( $(compgen -W "on off" -- ${cur}) )
        ;;
      host)
        COMPREPLY=( $(compgen -W "on off auto" -- ${cur}) )
        ;;
      path)
        COMPREPLY=( $(compgen -W "off full working-directory short-directory short-path mini-dir" -- ${cur}) )
        ;;
      config)
        COMPREPLY=( $(compgen -W "default load save" -- ${cur}) )
        ;;
      short-path)
        COMPREPLY=( $(compgen -W "add subtract" -- ${cur}) )
        ;;
      term)
        COMPREPLY=( $(compgen -W "xterm xterm-256color screen screen-256color" -- ${cur}) )
        ;;
    esac
  fi
}


__powerbash() {

  __powerbash_config() {
    POWERBASH_CONFIG_FILE="$HOME/.powerbash_config"
    POWERBASH_ICONS=( "⚑" "»" "♆" "☀" "♞" "☯" "☢" "❄" "+" )
    POWERBASH_ARROWS=( "⇠" "⇡" "⇢" "⇣" )
    DIM="\[$(tput dim)\]"
    REVERSE="\[$(tput rev)\]"
    RESET="\[$(tput sgr0)\]"
    BOLD="\[$(tput bold)\]"

    declare -A POWERBASH_CONFIG=(
      [POWERBASH_GIT_BRANCH_SYMBOL]=${POWERBASH_ICONS[1]}
      [POWERBASH_GIT_BRANCH_CHANGED_SYMBOL]=${POWERBASH_ICONS[8]}
      [POWERBASH_GIT_NEED_PUSH_SYMBOL]=${POWERBASH_ARROWS[1]}
      [POWERBASH_GIT_NEED_PULL_SYMBOL]=${POWERBASH_ARROWS[3]}
      [POWERBASH_USER]="on"
      [POWERBASH_HOST]="auto"
      [POWERBASH_PATH]="short-directoy"
      [POWERBASH_GIT]="on"
      [POWERBASH_JOBS]="on"
      [POWERBASH_SYMBOL]="on"
      [POWERBASH_RC]="on"
      [POWERBASH_SHORT_NUM]=20
    )
    if [ -z "${POWERBASH_SYSTEM_PS1}" ]; then POWERBASH_CONFIG[POWERBASH_SYSTEM_PS1]="$PS1"; fi

    case "$1" in
      default)
        for K in "${!POWERBASH_CONFIG[@]}"; do
          export $K="${POWERBASH_CONFIG[$K]}"
        done
        ;;
      load)
        if [ -e "${POWERBASH_CONFIG_FILE}" ]; then
          while read p; do
            [[ ! "$p" =~ ^# ]] && export $p
          done <${POWERBASH_CONFIG_FILE}
        fi
        ;;
      save)
        echo "# powerbash configuration" > ${POWERBASH_CONFIG_FILE}
        for K in "${!POWERBASH_CONFIG[@]}"; do
          echo "$K=$(eval echo \$${K})" >> ${POWERBASH_CONFIG_FILE}
        done
        ;;
    esac
  }
  __powerbash_config "default"
  __powerbash_config "load"

  __powerbash_colors() {
    if (( $(tput colors) < 256 )); then
      # 8 color support
      COLOR_USER="\[$(tput setaf 7)\]\[$(tput setab 4)\]"
      COLOR_SUDO="\[$(tput setaf 3)\]\[$(tput setab 4)\]"
      COLOR_SSH="\[$(tput setaf 3)\]\[$(tput setab 4)\]"
      COLOR_DIR="\[$(tput setaf 7)\]\[$(tput setab 4)\]"
      COLOR_GIT="\[$(tput setaf 7)\]\[$(tput setab 6)\]"
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
      COLOR_SYMBOL_USER="\[$(tput setaf 15)\]\[$(tput setab 2)\]"
      COLOR_SYMBOL_ROOT="\[$(tput setaf 15)\]\[$(tput setab 1)\]"
    fi
  }


  __powerbash_git_info() { 
    [ "$POWERBASH_GIT" == "off" ] && return # disable display
    [ -x "$(which git)" ] || return    # git not found

    # get current branch name or short SHA1 hash for detached head
    local branch="$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)"
    [ -n "$branch" ] || return  # git branch not found

    local marks

    # branch is modified?
    [ -n "$(git status --porcelain)" ] && marks+=" $POWERBASH_GIT_BRANCH_CHANGED_SYMBOL"

    # how many commits local branch is ahead/behind of remote?
    local stat="$(git status --porcelain --branch | head -n1)"
    local aheadN="$(echo $stat | grep -o 'ahead [0-9]*' | grep -o '[0-9]')"
    local behindN="$(echo $stat | grep -o 'behind [0-9]*' | grep -o '[0-9]')"
    [ -n "$aheadN" ] && marks+=" $POWERBASH_GIT_NEED_PUSH_SYMBOL$aheadN"
    [ -n "$behindN" ] && marks+=" $POWERBASH_GIT_NEED_PULL_SYMBOL$behindN"

    # print the git branch segment without a trailing newline
    printf "$(echo -n "$COLOR_GIT $POWERBASH_GIT_BRANCH_SYMBOL$branch$marks $RESET" | tr '\n' ' ')"
  }

  __powerbash_user_display() {
    [ "$POWERBASH_USER" == "off" ] && return # disable display

    # check if running sudo
    [ -n "$SUDO_USER" ] && local IS_SUDO="$COLOR_SUDO"
    [[ -z "$POWERBASH_USER" || "$POWERBASH_USER" == "on" ]] && printf "$COLOR_USER$IS_SUDO \\\u $RESET"
  }

  __powerbash_host_display() {
    [ "$POWERBASH_HOST" == "off" ] && return # disable display

    # check if on or ssh session
    [[ "$POWERBASH_HOST" == "on" || "$POWERBASH_HOST" == "auto" && -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && printf "$COLOR_SSH@\\h $RESET"
  }

  __powerbash_short_dir() {
    local dir_split_count=4
    local short_dir="$PWD"
    local dir_array=""

    IFS='/' read -a dir_array <<< "$PWD"
    if [ ${#dir_array[@]} -gt $dir_split_count ]; then
      short_dir="/${dir_array[1]}/.../${dir_array[${#dir_array[@]}-2]}/${dir_array[${#dir_array[@]}-1]}"
    fi

    printf "$short_dir"
  }

  __powerbash_short_path() {
    local short_num="$POWERBASH_SHORT_NUM"
    local short_path=$PWD

    [[ ${#PWD} > $short_num ]] && short_path="..${PWD: -$short_num}"

    printf "$short_path"
  }

  __powerbash_mini_dir() {
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

  __powerbash_short_num_change() {
    [ -n $2 ] && local NUMBER="$2" #add/subtract by $2 when provided
    [ -z "$NUMBER" ] && local NUMBER="1" #default add/subtract by 1
    [ "$1" == "subtract" ] && ((POWERBASH_SHORT_NUM-=$NUMBER))
    [ "$1" == "add" ] && ((POWERBASH_SHORT_NUM+=$NUMBER))
    return 0
  }

  __powerbash_dir_display() {
    [ "$POWERBASH_PATH" == "off" ] && return # disable display

    local dir_display=""
    case "$POWERBASH_PATH" in
      full)               dir_display="\\w" ;;
      working-directory)  dir_display="\\W" ;;
      short-path)         dir_display="$(__powerbash_short_path)" ;;
      short-directory)    dir_display="$(__powerbash_short_dir)" ;;
      mini-dir)           dir_display="$(__powerbash_mini_dir)" ;;
      *)                  dir_display="\\W" ;;
    esac

    [ "$dir_display" == "$HOME" ] && dir_display="~" # display ~ for home

    printf "$COLOR_DIR $dir_display $RESET"
  }

  __powerbash_jobs_display() {
    [ "$POWERBASH_JOBS" == "off" ] && return # disable display
    [ $(jobs | wc -l) -ne "0" ] && printf "$COLOR_JOBS \\j $RESET"
  }

  __powerbash_symbol_display() {
    [ "$POWERBASH_SYMBOL" == "off" ] && return # disable display

    # different color for root and regular user
    local symbol_bg=$COLOR_SYMBOL_USER
    [ $EUID -eq 0 ] && symbol_bg=$COLOR_SYMBOL_ROOT

    printf "$symbol_bg \\$ $RESET"
  }

  __powerbash_rc_display() {
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
        PS1+="$(__powerbash_user_display)"
        PS1+="$(__powerbash_host_display)"
        PS1+="$(__powerbash_dir_display)"
        PS1+="$(__powerbash_git_info)"
        PS1+="$(__powerbash_jobs_display)"
        PS1+="$(__powerbash_symbol_display)"
        PS1+="$(__powerbash_rc_display ${RETURN_CODE})"
        PS1+=" "
        ;;
    esac
  }

  # set prompt command
  PROMPT_COMMAND="__powerbash_ps1 on"
}

__powerbash
unset __powerbash
