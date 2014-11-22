#!/usr/bin/env bash

# enable auto completion
complete -F __powerbash_complete powerbash

# save system PS1
if [ -z "$POWERBASH_SYSTEM_PS1" ]; then POWERBASH_SYSTEM_PS1=$PS1; fi

# set default variables
if [ -z "$POWERBASH_SHORT_NUM" ]; then POWERBASH_SHORT_NUM=20; fi


powerbash() {
  case "$@" in
    "on")
      export PROMPT_COMMAND=__powerbash_ps1-on
      ;;
    "off")
      export PROMPT_COMMAND=__powerbash_ps1-off
      ;;
    "system")
      export PROMPT_COMMAND=__powerbash_ps1-system
      ;;
    "reload")
      source ~/.bashrc
      ;;
    "user on")
      export POWERBASH_USER="on"
      ;;
    "user off")
      export POWERBASH_USER="off"
      ;;
    "path off")
      export POWERBASH_PATH="off"
      ;;
    "path full")
      export POWERBASH_PATH="full"
      ;;
    "path working-directory")
      export POWERBASH_PATH="working-directory"
      ;;
    "path short-directory")
      export POWERBASH_PATH="short-directory"
      ;;
    "path short-path")
      export POWERBASH_PATH="short-path"
      ;;
    "path short-path add"*)
      __powerbash_short_num_change add $4
      ;;
    "path short-path subtract"*)
      __powerbash_short_num_change subtract $4
      ;;
    "term"*)
      export TERM=$2
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
  opts="on off system reload path user term"

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  elif [ $COMP_CWORD -ge 2 ]; then
    case "${prev}" in
      "user")
        COMPREPLY=( $(compgen -W "on off" -- ${cur}) )
        return 0
        ;;
      "path")
        COMPREPLY=( $(compgen -W "off full working-directory short-directory short-path" -- ${cur}) )
        return 0
        ;;
      "short-path")
        COMPREPLY=( $(compgen -W "add subtract" -- ${cur}) )
        return 0
        ;;
      "term")
        COMPREPLY=( $(compgen -W "xterm xterm-256colors screen screen-256colors" -- ${cur}) )
        return 0
        ;;
    esac
  fi
}


__powerbash() {
  # unicode symbols
  ICONS=( "⚑" "»" "♆" "☀" "♞" "☯" "☢" "❄" )
  ARROWS=( "⇠" "⇡" "⇢" "⇣" )
  GIT_BRANCH_SYMBOL=${ICONS[1]}
  GIT_BRANCH_CHANGED_SYMBOL='+'
  GIT_NEED_PUSH_SYMBOL=${ARROWS[1]}
  GIT_NEED_PULL_SYMBOL=${ARROWS[3]}

  # color specials
  DIM="\[$(tput dim)\]"
  REVERSE="\[$(tput rev)\]"
  RESET="\[$(tput sgr0)\]"
  BOLD="\[$(tput bold)\]"


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


  __powerbash_theme() {
  local theme=$1
  if [ $theme == default8 ];then 
    COLOR_USER="\[$(tput setaf 7)\]\[$(tput setab 4)\]"
    COLOR_SUDO="\[$(tput setaf 3)\]\[$(tput setab 4)\]"
    COLOR_SSH="\[$(tput setaf 3)\]\[$(tput setab 4)\]"
    COLOR_DIR="\[$(tput setaf 7)\]\[$(tput setab 4)\]"
    COLOR_GIT="\[$(tput setaf 7)\]\[$(tput setab 6)\]"
    COLOR_RC="\[$(tput setaf 7)\]\[$(tput setab 1)\]"
    COLOR_JOBS="\[$(tput setaf 7)\]\[$(tput setab 5)\]"
    COLOR_SYMBOL_USER="\[$(tput setaf 7)\]\[$(tput setab 2)\]"
    COLOR_SYMBOL_ROOT="\[$(tput setaf 7)\]\[$(tput setab 1)\]"
  fi
  if [ $theme == default256 ];then 
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

  __powerbash_user_display() {
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
    if [ "$POWERBASH_USER" != "off" ]; then printf "$COLOR_USER$IS_SUDO $USER$IS_SSH $RESET"; fi
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
   local NUMBER_DEFAULT=1
   if [ -z "$2" ];then
     NUMBER=$NUMBER_DEFAULT
   else
     NUMBER=$2
   fi
   if [ "$1" == "add" ]; then
     ((POWERBASH_SHORT_NUM+=$NUMBER))
   fi
   if [ "$1" == "subtract" ]; then
     ((POWERBASH_SHORT_NUM-=$NUMBER))
   fi
 }

 __powerbash_dir_display() {
   if [ "$POWERBASH_PATH" == "off" ]; then
     local DIR_DISPLAY=""
   elif [ "$PWD" == "/" ]; then
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
   if [ "$DIR_DISPLAY" != "" ]; then printf "$COLOR_DIR $DIR_DISPLAY $RESET"; fi
 }

 __powerbash_jobs_display() {
   local JOBS="$(jobs | wc -l)"
   if [ "$JOBS" -ne "0" ]; then
     local JOBS_DISPLAY="$COLOR_JOBS $JOBS $RESET"
   else
     local JOBS_DISPLAY=""
   fi
   printf "$JOBS_DISPLAY"
 }

 __powerbash_symbol_display() {
   # check if root or regular user
   if [ $EUID -ne 0 ]; then
     local SYMBOL_BG=$COLOR_SYMBOL_USER
   else
     local SYMBOL_BG=$COLOR_SYMBOL_ROOT
   fi
   printf "$SYMBOL_BG \\$ $RESET"
 }

 __powerbash_rc_display() {
   # check the exit code of the previous command and display different
   local rc=$1
   if [ $rc -ne 0 ]; then
     local RC_DISPLAY="$COLOR_RC $rc $RESET"
   else
     local RC_DISPLAY=""
   fi
   printf "$RC_DISPLAY"
 }

  __powerbash_ps1-system() {
    # set prompt
    PS1=$POWERBASH_SYSTEM_PS1 
  }

  __powerbash_ps1-off() {
    # set prompt
    PS1='\$ '
  }

  __powerbash_ps1-on() {
    # find supported colors
    if (( $(tput colors) < 256 )); then
      __powerbash_theme "default8"
    else
      __powerbash_theme "default256"
    fi

    # capture latest return code
    local RETURN_CODE=$?

    # set prompt
    PS1=""
    PS1+="$(__powerbash_user_display)"
    PS1+="$(__powerbash_dir_display)"
    PS1+="$(__powerbash_git_info)"
    PS1+="$(__powerbash_jobs_display)"
    PS1+="$(__powerbash_symbol_display)"
    PS1+="$(__powerbash_rc_display ${RETURN_CODE})"
    PS1+=" "
  }

  PROMPT_COMMAND=__powerbash_ps1-on
}

__powerbash
unset __powerbash
