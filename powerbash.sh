#!/usr/bin/env bash
#

# enable auto completion
complete -F __powerbash_complete powerbash

# save system PS1
[ -z "$POWERBASH_SYSTEM_PS1" ] && POWERBASH_SYSTEM_PS1=$PS1

# set default variables
[ -z "$POWERBASH_SHORT_NUM" ] && POWERBASH_SHORT_NUM=20


powerbash() {
  case "$@" in
    @(on|off|system))
     export PROMPT_COMMAND="__powerbash_ps1 $1"
     ;;
    reload)
      source ~/.bashrc
      ;;
    @(user|host|path|git|jobs|symbol|rc)\ @(on|off))
      export "POWERBASH_${1^^}"="$2"
      ;;
    path\ @(full|working-directory|short-directory|short-path))
      export "POWERBASH_${1^^}"="$2"
      ;;
    path\ short-path\ @(add|subtract))
      __powerbash_short_num_change $3 $4
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
  opts="on off system reload path user host jobs git symbol rc term"

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  elif [ $COMP_CWORD -ge 2 ]; then
    case "${prev}" in
      @(user|host|jobs|git|symbol|rc))
        COMPREPLY=( $(compgen -W "on off" -- ${cur}) )
        ;;
      path)
        COMPREPLY=( $(compgen -W "off full working-directory short-directory short-path" -- ${cur}) )
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

  # unicode symbols
  ICONS=( "⚑" "»" "♆" "☀" "♞" "☯" "☢" "❄" "+" )
  ARROWS=( "⇠" "⇡" "⇢" "⇣" )
  GIT_BRANCH_SYMBOL=${ICONS[1]}
  GIT_BRANCH_CHANGED_SYMBOL=${ICONS[8]}
  GIT_NEED_PUSH_SYMBOL=${ARROWS[1]}
  GIT_NEED_PULL_SYMBOL=${ARROWS[3]}

  # color specials
  DIM="\[$(tput dim)\]"
  REVERSE="\[$(tput rev)\]"
  RESET="\[$(tput sgr0)\]"
  BOLD="\[$(tput bold)\]"

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
    [ -n "$(git status --porcelain)" ] && marks+=" $GIT_BRANCH_CHANGED_SYMBOL"

    # how many commits local branch is ahead/behind of remote?
    local stat="$(git status --porcelain --branch | head -n1)"
    local aheadN="$(echo $stat | grep -o 'ahead [0-9]*' | grep -o '[0-9]*')"
    local behindN="$(echo $stat | grep -o 'behind [0-9]*' | grep -o '[0-9]*')"
    [ -n "$aheadN" ] && marks+=" $GIT_NEED_PUSH_SYMBOL$aheadN"
    [ -n "$behindN" ] && marks+=" $GIT_NEED_PULL_SYMBOL$behindN"

    printf "$COLOR_GIT $GIT_BRANCH_SYMBOL$branch$marks $RESET"
  }

  __powerbash_user_display() {
    [ "$POWERBASH_USER" == "off" ] && return # disable display

    # check if running sudo
    [ -n "$SUDO_USER" ] && IS_SUDO="$COLOR_SUDO"

    [ "$POWERBASH_USER" == "on" ] &&
      printf "$COLOR_USER$IS_SUDO $USER $RESET"
  }

  __powerbash_host_display() {
    [ "$POWERBASH_HOST" == "off" ] && return # disable display

    # check if ssh session
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then local IS_SSH=1; fi

    [[ "$POWERBASH_HOST" == "on" || "$IS_SSH" -eq 1 ]] &&
      printf "$COLOR_SSH@$(hostname -s) $RESET"
  }

  __powerbash_short_dir() {
    local DIR_SPLIT_COUNT=4
    IFS='/' read -a DIR_ARRAY <<< "$PWD"
    if [ ${#DIR_ARRAY[@]} -gt $DIR_SPLIT_COUNT ]; then
      local SHORT_DIR="/${DIR_ARRAY[1]}/.../${DIR_ARRAY[${#DIR_ARRAY[@]}-2]}/${DIR_ARRAY[${#DIR_ARRAY[@]}-1]}"
    else
      local SHORT_DIR="$PWD"
    fi
    printf "$SHORT_DIR"
  }

  __powerbash_short_path() {
    local SHORT_NUM="$POWERBASH_SHORT_NUM"
    if (( ${#PWD} > $SHORT_NUM )); then
      local SHORT_PATH="..${PWD: -$SHORT_NUM}"
    else
      local SHORT_PATH=$PWD
    fi
    printf "$SHORT_PATH"
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

   if [ "$PWD" == "/" ]; then
     local DIR_DISPLAY="/"
   elif [ "$HOME" == "$PWD" ]; then
     local DIR_DISPLAY="~"
   elif [ "$POWERBASH_PATH" == "full" ]; then
     local DIR_DISPLAY=$PWD
   elif [ "$POWERBASH_PATH" == "working-directory" ]; then
     local DIR_DISPLAY="${PWD##*/}"
   elif [ "$POWERBASH_PATH" == "short-directory" ]; then
     local DIR_DISPLAY=$(__powerbash_short_dir)
   elif [ "$POWERBASH_PATH" == "short-path" ]; then
     local DIR_DISPLAY=$(__powerbash_short_path)
   else
     local DIR_DISPLAY="${PWD##*/}"
   fi
   printf "$COLOR_DIR $DIR_DISPLAY $RESET"
 }

 __powerbash_jobs_display() {
   [ "$POWERBASH_JOBS" == "off" ] && return # disable display

   local JOBS="$(jobs | wc -l)"
   if [ "$JOBS" -ne "0" ]; then
     local JOBS_DISPLAY="$COLOR_JOBS $JOBS $RESET"
   else
     local JOBS_DISPLAY=""
   fi
   printf "$JOBS_DISPLAY"
 }

 __powerbash_symbol_display() {
   [ "$POWERBASH_SYMBOL" == "off" ] && return # disable display

   # check if root or regular user
   if [ $EUID -ne 0 ]; then
     local SYMBOL_BG=$COLOR_SYMBOL_USER
   else
     local SYMBOL_BG=$COLOR_SYMBOL_ROOT
   fi
   printf "$SYMBOL_BG \\$ $RESET"
 }

 __powerbash_rc_display() {
   [ "$POWERBASH_RC" == "off" ] && return # disable display

   # check the exit code of the previous command and display different
   local rc=$1
   if [ $rc -ne 0 ]; then
     local RC_DISPLAY="$COLOR_RC $rc $RESET"
   else
     local RC_DISPLAY=""
   fi
   printf "$RC_DISPLAY"
 }

  __powerbash_ps1() {
    # keep this at top!!!
    # capture latest return code
    local RETURN_CODE=$?
    
    case "$1" in
      off)    PS1='\$ ' ;;
      system) PS1=$POWERBASH_SYSTEM_PS1 ;;
      on)
        # Check for supported colors
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

  PROMPT_COMMAND="__powerbash_ps1 on"
}

__powerbash
unset __powerbash
