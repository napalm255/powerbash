#!/usr/bin/env bash
#
# powerbash - powerline-style bash prompt in pure bash.
#
# Requires bash 3.2+ (so stock macOS /bin/bash works). Keep it that way:
# no ${var^^}, no mapfile/readarray, no associative arrays, and no GNU-only
# tool flags -- macOS ships BSD userland.

# Only meaningful under bash. /etc/profile is also sourced by dash on
# Debian/Ubuntu sh login shells, where [[ ]] is a syntax error.
[ -n "$BASH_VERSION" ] || return 0

# exit for non-interactive
[ -z "$PS1" ] && return 0

POWERBASH_VERSION="2.0.1"

# Settings that are persisted to / loaded from the config file. Anything not
# in this list is never written and never read back, so a hand-edited or
# poisoned config cannot inject arbitrary variables into the environment.
__POWERBASH_SETTINGS="POWERBASH_USER POWERBASH_HOST POWERBASH_PATH \
POWERBASH_PATH_SHORT_LENGTH POWERBASH_GIT POWERBASH_GIT_SKIP_PATHS \
POWERBASH_GIT_TIMEOUT POWERBASH_JOBS POWERBASH_SYMBOL POWERBASH_RC \
POWERBASH_PY_VIRTUALENV"

# tput, but never noisy and never fatal. With no $TERM (cron, CI, a container
# with no TTY) tput writes to stderr and exits non-zero, which under `set -e`
# aborts the whole sourcing. Swallow both: no terminfo means no colors, which
# is exactly the graceful degradation the docs promise. Defined at top level
# because __powerbash uses it before it defines its own nested functions.
__powerbash_tput() { tput "$@" 2>/dev/null || :; }

__powerbash_usage() {
  cat <<'EOF'
usage: powerbash <command> [options]

  help                    show this message
  version                 show the powerbash version
  reload                  re-source your bash startup file

  prompt   on|off|system  enable, disable, or restore the original prompt
  config   default|load|save
                          reset to defaults, or load/save ~/.config/powerbashrc

  user     on|off         username segment
  host     on|off|auto    hostname segment (auto = only over ssh)
  jobs     on|off         background job count segment
  symbol   on|off         $/# prompt symbol segment
  rc       on|off         return code segment (shown when non-zero)

  path     off|full|working|parted|mini
           short [add|subtract [N]]
                          working directory segment and its display mode

  git      on|off         git branch/status segment
  git      skip [paths]   colon-separated path prefixes to skip git in
  git      timeout [secs] cap how long the git lookup may take (needs
                          timeout/gtimeout; empty or 0 disables)

  py virtualenv on|off|icon|short
                          python/conda virtualenv segment

  term     xterm|xterm-256color|screen|screen-256color
                          set TERM and recompute colors
EOF
}

powerbash() {
  case "$1" in
    help|-h|--help) __powerbash_usage ;;
    version|--version) echo "powerbash $POWERBASH_VERSION" ;;
    reload)
      # macOS Terminal runs login shells, which read ~/.bash_profile.
      local rcfile=""
      [ -r "$HOME/.bashrc" ] && rcfile="$HOME/.bashrc"
      [ -z "$rcfile" ] && [ -r "$HOME/.bash_profile" ] && rcfile="$HOME/.bash_profile"
      if [ -z "$rcfile" ]; then
        echo "powerbash: no ~/.bashrc or ~/.bash_profile to reload" >&2
        return 1
      fi
      # shellcheck source=/dev/null
      source "$rcfile"
      ;;
    prompt)
      case "$2" in
        on|off|system) __powerbash_set_prompt_command "$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    config)
      case "$2" in
        default|load|save) __powerbash_config "$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    py)
      case "$2" in
        virtualenv)
          case "$3" in
            on|off|icon|short) export POWERBASH_PY_VIRTUALENV="$3" ;;
            *) __powerbash_usage; return 1 ;;
          esac
          ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    user)
      case "$2" in
        on|off) export POWERBASH_USER="$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    jobs)
      case "$2" in
        on|off) export POWERBASH_JOBS="$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    symbol)
      case "$2" in
        on|off) export POWERBASH_SYMBOL="$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    rc)
      case "$2" in
        on|off) export POWERBASH_RC="$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    git)
      case "$2" in
        on|off) export POWERBASH_GIT="$2" ;;
        skip) export POWERBASH_GIT_SKIP_PATHS="$3" ;;
        timeout) __powerbash_git_timeout "$3" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    host)
      case "$2" in
        on|off|auto) export POWERBASH_HOST="$2" ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    path)
      case "$2" in
        off|full|working|parted|mini) export POWERBASH_PATH="$2" ;;
        short)
          export POWERBASH_PATH="$2"
          case "$3" in
            "") ;;
            add|subtract) __powerbash_path_short_length "$3" "$4" ;;
            *) __powerbash_usage; return 1 ;;
          esac
          ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    term)
      case "$2" in
        xterm|xterm-256color|screen|screen-256color)
          export TERM="$2"; __powerbash_colors ;;
        *) __powerbash_usage; return 1 ;;
      esac
      ;;
    *) __powerbash_usage; return 1 ;;
  esac
}

__powerbash_complete() {
  local cur prev option_list
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [ "$COMP_CWORD" -eq 1 ]; then
    # first level options
    option_list="help version reload prompt config py user host path git jobs symbol rc term"
  elif [ "$COMP_CWORD" -eq 2 ]; then
    # second level options
    case "${prev}" in
      prompt) option_list="on off system" ;;
      config) option_list="default load save" ;;
          py) option_list="virtualenv" ;;
        user) option_list="on off" ;;
        host) option_list="on off auto" ;;
        path) option_list="off full working short parted mini" ;;
         git) option_list="on off skip timeout" ;;
        jobs) option_list="on off" ;;
      symbol) option_list="on off" ;;
          rc) option_list="on off" ;;
        term) option_list="xterm xterm-256color screen screen-256color" ;;
    esac
  elif [ "$COMP_CWORD" -eq 3 ]; then
    # third level options
    case "${prev}" in
      virtualenv) option_list="on off icon short" ;;
      short) option_list="add subtract" ;;
    esac
  fi
  # mapfile is bash 4+; this idiom keeps stock macOS bash 3.2 working. Safe
  # because every option value above is a known, space-free literal.
  # shellcheck disable=SC2207
  COMPREPLY=( $(compgen -W "${option_list}" -- "${cur}") )
}

__powerbash() {
  # segment symbols
  POWERBASH_PY_VIRTUALENV_SYMBOL="▶"
  POWERBASH_GIT_BRANCH_SYMBOL="»"
  POWERBASH_GIT_BRANCH_CHANGED_SYMBOL="+"
  POWERBASH_GIT_NEED_PUSH_SYMBOL="⇡"
  POWERBASH_GIT_NEED_PULL_SYMBOL="⇣"
  RESET="\[$(__powerbash_tput sgr0)\]"

  # Resolved once: GNU coreutils installs as gtimeout on macOS via Homebrew.
  __POWERBASH_TIMEOUT_CMD=""
  if command -v timeout >/dev/null 2>&1; then
    __POWERBASH_TIMEOUT_CMD="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    __POWERBASH_TIMEOUT_CMD="gtimeout"
  fi

  # Resolved once: bash runs every element of an array PROMPT_COMMAND as of
  # 5.1. Older bash expands it as a plain string, which yields element 0 and
  # silently drops every other hook -- so the array form must never be
  # created there. BASH_VERSINFO goes back to bash 2.0, so this is safe on
  # the 3.2 we support.
  __POWERBASH_PC_ARRAY="no"
  if [ "${BASH_VERSINFO[0]}" -gt 5 ] ||
     { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; }; then
    __POWERBASH_PC_ARRAY="yes"
  fi

  __powerbash_defaults() {
    [ -z "$POWERBASH_USER" ] && export POWERBASH_USER="on"
    [ -z "$POWERBASH_HOST" ] && export POWERBASH_HOST="auto"
    [ -z "$POWERBASH_PATH" ] && export POWERBASH_PATH="working"
    [ -z "$POWERBASH_PATH_SHORT_LENGTH" ] && export POWERBASH_PATH_SHORT_LENGTH=20
    [ -z "$POWERBASH_GIT" ] && export POWERBASH_GIT="on"
    [ -z "$POWERBASH_JOBS" ] && export POWERBASH_JOBS="on"
    [ -z "$POWERBASH_SYMBOL" ] && export POWERBASH_SYMBOL="on"
    [ -z "$POWERBASH_RC" ] && export POWERBASH_RC="on"
    [ -z "$POWERBASH_PY_VIRTUALENV" ] && export POWERBASH_PY_VIRTUALENV="on"

    # Git on WSL's /mnt/* (Windows filesystem) is slow enough to stall the
    # prompt, so default to skipping it there and nowhere else.
    if [ -z "${POWERBASH_GIT_SKIP_PATHS}" ] && [ -z "${__POWERBASH_SKIP_DEFAULTED}" ]; then
      __POWERBASH_SKIP_DEFAULTED=1
      if [ -n "$WSL_DISTRO_NAME" ]; then
        export POWERBASH_GIT_SKIP_PATHS="/mnt/"
      elif [ -r /proc/version ]; then
        case "$(< /proc/version)" in
          *icrosoft*) export POWERBASH_GIT_SKIP_PATHS="/mnt/" ;;
        esac
      fi
    fi
    return 0
  }

  # Escape content that gets embedded in PS1. Bash expands PS1 on every
  # render (promptvars), so an unescaped $(...), backtick, or backslash
  # escape in a directory or branch name would be executed or would corrupt
  # the prompt's width accounting. Result lands in __powerbash_esc so this
  # costs no subshell.
  __powerbash_escape() {
    __powerbash_esc="${1//\\/\\\\}"
    __powerbash_esc="${__powerbash_esc//\$/\\\$}"
    __powerbash_esc="${__powerbash_esc//\`/\\\`}"
  }

  __powerbash_config() {
    local name value line dir
    case "$1" in
      default)
        [ -e "$POWERBASH_CONFIG" ] && rm -f "$POWERBASH_CONFIG"
        for name in $__POWERBASH_SETTINGS; do
          unset "$name"
        done
        __powerbash_defaults
        ;;
      load)
        [ -r "$POWERBASH_CONFIG" ] || return 0
        while IFS= read -r line; do
          case "$line" in ''|'#'*) continue ;; esac
          name="${line%%=*}"
          value="${line#*=}"
          # only known settings, so a tampered file cannot export anything else
          case " $__POWERBASH_SETTINGS " in
            *" $name "*) export "$name=$value" ;;
          esac
        done < "$POWERBASH_CONFIG"
        ;;
      save)
        dir="${POWERBASH_CONFIG%/*}"
        [ -n "$dir" ] && [ ! -d "$dir" ] && { mkdir -p "$dir" || return 1; }
        : > "$POWERBASH_CONFIG" || return 1
        for name in $__POWERBASH_SETTINGS; do
          value="${!name}"
          [ -n "$value" ] && printf '%s=%s\n' "$name" "$value"
        done >> "$POWERBASH_CONFIG"
        ;;
    esac
  }

  __powerbash_colors() {
    local count
    count="$(__powerbash_tput colors)"
    # Anything not a plain non-negative integer (empty when there is no
    # terminfo entry, "-1" on a dumb terminal) means "assume 8 colors".
    case "$count" in
      "" | *[!0-9]*) count=8 ;;
    esac

    if [ "$count" -lt 256 ]; then
      # 8 color support
      COLOR_USER="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 0)\]"
      COLOR_SUDO="\[$(__powerbash_tput setaf 3)\]\[$(__powerbash_tput setab 0)\]"
      COLOR_SSH="\[$(__powerbash_tput setaf 3)\]\[$(__powerbash_tput setab 0)\]"
      COLOR_DIR="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 0)\]"
      COLOR_GIT="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 4)\]"
      COLOR_RC="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 1)\]"
      COLOR_JOBS="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 5)\]"
      COLOR_PY_VIRTUALENV="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 5)\]"
      COLOR_SYMBOL_USER="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 2)\]"
      COLOR_SYMBOL_ROOT="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 1)\]"
    else
      # 256 color support
      COLOR_USER="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 8)\]"
      COLOR_SUDO="\[$(__powerbash_tput setaf 3)\]\[$(__powerbash_tput setab 8)\]"
      COLOR_SSH="\[$(__powerbash_tput setaf 3)\]\[$(__powerbash_tput setab 8)\]"
      COLOR_DIR="\[$(__powerbash_tput setaf 7)\]\[$(__powerbash_tput setab 8)\]"
      COLOR_GIT="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 4)\]"
      COLOR_RC="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 9)\]"
      COLOR_JOBS="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 5)\]"
      COLOR_PY_VIRTUALENV="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 5)\]"
      COLOR_SYMBOL_USER="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 2)\]"
      COLOR_SYMBOL_ROOT="\[$(__powerbash_tput setaf 15)\]\[$(__powerbash_tput setab 1)\]"
    fi
  }

  # Renderers append to PS1 directly rather than printing for capture -- a
  # $(...) per segment would fork a subshell on every prompt draw. They must
  # therefore keep all working state local and never assign to config
  # globals, since there is no subshell to contain the writes.

  __powerbash_py_virtualenv_display() {
    [ "$POWERBASH_PY_VIRTUALENV" = "off" ] && return 0

    # get virtualenv name (py or conda)
    local venv_name=""
    [ -n "$VIRTUAL_ENV" ] && venv_name="$VIRTUAL_ENV"
    [ -n "$CONDA_DEFAULT_ENV" ] && venv_name="$CONDA_DEFAULT_ENV"
    [ -n "$venv_name" ] || return 0

    venv_name="${venv_name##*/}"
    __powerbash_escape "$venv_name"

    local venv="$POWERBASH_PY_VIRTUALENV_SYMBOL"
    case "$POWERBASH_PY_VIRTUALENV" in
      icon) ;;
      short) venv="$venv ${__powerbash_esc:0:5}" ;;
      *)     venv="$venv $__powerbash_esc" ;;
    esac

    PS1+="$COLOR_PY_VIRTUALENV $venv $RESET"
  }

  __powerbash_git_display() {
    [ "$POWERBASH_GIT" = "off" ] && return 0
    command -v git >/dev/null 2>&1 || return 0 # git not found

    # Cheapest guard first: skip entire path prefixes (WSL /mnt/* by
    # default) without paying for a git invocation at all.
    if [ -n "$POWERBASH_GIT_SKIP_PATHS" ]; then
      local skip_list skip_one
      IFS=':' read -ra skip_list <<< "$POWERBASH_GIT_SKIP_PATHS"
      for skip_one in "${skip_list[@]}"; do
        [ -n "$skip_one" ] || continue
        case "$PWD" in "$skip_one"*) return 0 ;; esac
      done
    fi

    # one call gets branch/head, upstream ahead/behind, and dirty status.
    # `|| rc=$?` rather than a bare assignment plus `rc=$?`: git exits 128
    # outside a work tree, and under `set -e` a failing command substitution
    # in an assignment aborts the shell before the status can be read.
    local git_status rc=0 top
    if [ -n "$POWERBASH_GIT_TIMEOUT" ] && [ -n "$__POWERBASH_TIMEOUT_CMD" ]; then
      git_status="$("$__POWERBASH_TIMEOUT_CMD" "$POWERBASH_GIT_TIMEOUT" \
        git status --porcelain=v2 --branch 2>/dev/null)" || rc=$?
    else
      git_status="$(git status --porcelain=v2 --branch 2>/dev/null)" || rc=$?
    fi
    [ "$rc" -eq 124 ] && return 0 # timed out
    if [ "$rc" -ne 0 ]; then
      # Not a normal work tree -- e.g. inside .git/ itself, or a linked
      # worktree's admin dir. `git rev-parse --show-toplevel` fails with the
      # exact same error in this case, so it can't locate the work tree;
      # `git worktree list` can, because it reads repository metadata
      # rather than requiring one. Its --porcelain form is line-oriented
      # and needs no sed. Keyed off the exit code rather than a localized
      # error string.
      local wt_line
      while IFS= read -r wt_line; do
        case "$wt_line" in
          "worktree "*) top="${wt_line#worktree }"; break ;;
        esac
      done < <(git worktree list --porcelain 2>/dev/null)
      [ -n "$top" ] || return 0
      git_status="$(git -C "$top" status --porcelain=v2 --branch 2>/dev/null)" || return 0
    fi

    local branch="" ahead="" behind="" dirty="" line ab
    while IFS= read -r line; do
      case "$line" in
        "# branch.head "*) branch="${line#\# branch.head }" ;;
        "# branch.ab "*)
          ab="${line#\# branch.ab }"
          ahead="${ab%% *}"
          behind="${ab##* }"
          ahead="${ahead#+}"
          behind="${behind#-}"
          ;;
        "#"*) ;; # other header lines, ignore
        *) dirty="1" ;; # any non-header line means the tree is dirty
      esac
    done <<< "$git_status"
    [ -n "$branch" ] || return 0 # git branch not found

    # detached HEAD: fall back to a friendly tag/SHA label
    if [ "$branch" = "(detached)" ]; then
      branch="$(git describe --tags --always 2>/dev/null || :)"
      [ -n "$branch" ] || return 0
    fi

    # A branch name can contain $(...) or backticks; never let PS1 expand it.
    __powerbash_escape "$branch"

    local marks=""
    [ -n "$dirty" ] && marks="$marks $POWERBASH_GIT_BRANCH_CHANGED_SYMBOL"
    [ -n "$ahead" ] && [ "$ahead" -gt 0 ] && marks="$marks $POWERBASH_GIT_NEED_PUSH_SYMBOL$ahead"
    [ -n "$behind" ] && [ "$behind" -gt 0 ] && marks="$marks $POWERBASH_GIT_NEED_PULL_SYMBOL$behind"

    PS1+="$COLOR_GIT $POWERBASH_GIT_BRANCH_SYMBOL$__powerbash_esc$marks $RESET"
  }

  __powerbash_user_display() {
    [ "$POWERBASH_USER" = "on" ] || return 0
    local color="$COLOR_USER"
    [ -n "$SUDO_USER" ] && color="$COLOR_SUDO"
    PS1+="$color \\u $RESET"
  }

  __powerbash_host_display() {
    local show="$POWERBASH_HOST"
    if [ "$show" = "auto" ]; then
      if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then show="on"; else show="off"; fi
    fi
    [ "$show" = "on" ] || return 0
    PS1+="$COLOR_SSH@\\h $RESET"
  }

  __powerbash_path_parted() {
    local dir_split_count=4
    local dir_array
    IFS='/' read -ra dir_array <<< "$PWD"
    if [ ${#dir_array[@]} -gt "$dir_split_count" ]; then
      __powerbash_path_out="/${dir_array[1]}/.../${dir_array[${#dir_array[@]}-2]}/${dir_array[${#dir_array[@]}-1]}"
    else
      __powerbash_path_out="$PWD"
    fi
  }

  __powerbash_path_short() {
    __powerbash_path_out="$PWD"
    if [ "${#PWD}" -gt "$POWERBASH_PATH_SHORT_LENGTH" ]; then
      __powerbash_path_out="..${PWD: -$POWERBASH_PATH_SHORT_LENGTH}"
    fi
  }

  __powerbash_path_short_length() {
    local length="${2:-1}"
    # This value reaches an arithmetic context, where bash performs command
    # substitution on array subscripts -- so it must be digits and nothing else.
    case "$length" in
      *[!0-9]*|'') echo "powerbash: length must be a positive integer" >&2; return 1 ;;
    esac

    if [ "$1" = "subtract" ]; then
      POWERBASH_PATH_SHORT_LENGTH=$((POWERBASH_PATH_SHORT_LENGTH - length))
    else
      POWERBASH_PATH_SHORT_LENGTH=$((POWERBASH_PATH_SHORT_LENGTH + length))
    fi
    # a non-positive length renders the whole path as ".." with no way back
    [ "$POWERBASH_PATH_SHORT_LENGTH" -lt 1 ] && POWERBASH_PATH_SHORT_LENGTH=1
    export POWERBASH_PATH_SHORT_LENGTH
    return 0
  }

  __powerbash_path_mini() {
    local current_path="${PWD/#$HOME/\~}"
    local parts prefix="" out="" i last
    case "$current_path" in /*) prefix="/" ;; esac
    IFS='/' read -ra parts <<< "$current_path"
    last=$(( ${#parts[@]} - 1 ))
    for (( i=0; i<last; i++ )); do
      # an absolute path splits with an empty leading field; skipping it is
      # what keeps the result from starting with a doubled slash
      [ -n "${parts[$i]}" ] || continue
      out="$out${parts[$i]:0:1}/"
    done
    __powerbash_path_out="$prefix$out${parts[$last]}"
  }

  __powerbash_path_display() {
    [ "$POWERBASH_PATH" = "off" ] && return 0

    # local, so that visiting $HOME does not permanently rewrite the setting
    local mode="$POWERBASH_PATH"
    [ "$PWD" = "$HOME" ] && mode="home"

    local dir_display=""
    case "$mode" in
         home) dir_display="~" ;;
         full) dir_display="\\w" ;;
      working) dir_display="\\W" ;;
        short) __powerbash_path_short;  __powerbash_escape "$__powerbash_path_out"; dir_display="$__powerbash_esc" ;;
       parted) __powerbash_path_parted; __powerbash_escape "$__powerbash_path_out"; dir_display="$__powerbash_esc" ;;
         mini) __powerbash_path_mini;   __powerbash_escape "$__powerbash_path_out"; dir_display="$__powerbash_esc" ;;
            *) return 0 ;;
    esac

    PS1+="$COLOR_DIR $dir_display $RESET"
  }

  __powerbash_jobs_display() {
    [ "$POWERBASH_JOBS" = "off" ] && return 0
    # jobs -p in one substitution; jobs | wc -l would fork an extra process
    [ -n "$(jobs -p)" ] && PS1+="$COLOR_JOBS \\j $RESET"
    return 0
  }

  __powerbash_symbol_display() {
    [ "$POWERBASH_SYMBOL" = "off" ] && return 0

    # different color for root and regular user
    local symbol_bg="$COLOR_SYMBOL_USER"
    [ "$EUID" -eq 0 ] && symbol_bg="$COLOR_SYMBOL_ROOT"

    PS1+="$symbol_bg \\\$ $RESET"
  }

  __powerbash_rc_display() {
    [ "$POWERBASH_RC" = "off" ] && return 0
    [ "$1" -ne 0 ] && PS1+="$COLOR_RC $1 $RESET"
    return 0
  }

  __powerbash_git_timeout() {
    case "$1" in
      ''|0) unset POWERBASH_GIT_TIMEOUT; return 0 ;;
      *[!0-9.]*|*.*.*) echo "powerbash: timeout must be a number of seconds" >&2; return 1 ;;
    esac
    if [ -z "$__POWERBASH_TIMEOUT_CMD" ]; then
      echo "powerbash: no timeout/gtimeout found; install GNU coreutils or use 'powerbash git skip'" >&2
      return 1
    fi
    export POWERBASH_GIT_TIMEOUT="$1"
  }

  __powerbash_set_ps1() {
    # keep this at top!!!
    # capture latest return code
    local RETURN_CODE=$?

    case "$1" in
      off)    PS1='\$ ' ;;
      system) PS1=$POWERBASH_SYSTEM_PS1 ;;
      on)
        # set prompt
        PS1=""
        __powerbash_py_virtualenv_display
        __powerbash_user_display
        __powerbash_host_display
        __powerbash_path_display
        __powerbash_git_display
        __powerbash_jobs_display
        __powerbash_symbol_display
        __powerbash_rc_display "$RETURN_CODE"
        PS1+=" "
        ;;
    esac
  }

  __powerbash_set_prompt_command() {
    # Play nice with other scripts that may also use PROMPT_COMMAND,
    # such as direnv and vte_prompt_command.
    # Colors depend on terminal capabilities (tput), not on anything that
    # changes per-prompt, so compute them here (on toggle) instead of in
    # __powerbash_set_ps1 (which runs on every prompt render).
    [ "$1" = "on" ] && __powerbash_colors

    # powerbash must run FIRST so that $? is still the user's command status
    # rather than the exit code of whatever else is registered.
    # The array-form and string-form branches below are mutually exclusive
    # at runtime, so shellcheck's array/string reassignment warning here
    # is a false positive.
    # shellcheck disable=SC2178,SC2128
    if [ -z "${PROMPT_COMMAND}" ]; then
      # Nothing registered yet, so we get to pick the type -- and the array
      # form is what keeps us installed at all. Scripts that register a hook
      # later commonly branch on `declare -p PROMPT_COMMAND`: given an array
      # they append, given a string they assign over the top of it and every
      # earlier hook is gone. GNOME Terminal's /etc/profile.d/vte.sh is the
      # one people actually hit -- its else-branch is a bare
      # `PROMPT_COMMAND="__vte_prompt_command"`. Handing it an array makes it
      # append instead, which is why a /etc/profile.d install no longer has
      # to be ordered after vte.sh on bash 5.1+. Below 5.1 the string is all
      # we can safely produce, so that ordering still matters there.
      if [ "$__POWERBASH_PC_ARRAY" = "yes" ]; then
        PROMPT_COMMAND=("__powerbash_set_ps1 $1")
      else
        PROMPT_COMMAND="__powerbash_set_ps1 $1"
      fi
    elif [[ "$(declare -p PROMPT_COMMAND 2>&1)" == "declare -a"* ]]; then
      # If PROMPT_COMMAND is an array (supported as of bash 5.1),
      # then an item is replaced or a new one is inserted at the front.
      local i changed="no"
      for (( i=0; i<${#PROMPT_COMMAND[@]}; i++ )); do
        case "${PROMPT_COMMAND[$i]}" in
          *__powerbash_set_ps1*)
            PROMPT_COMMAND[i]="__powerbash_set_ps1 $1"; changed="yes" ;;
        esac
      done
      if [ "$changed" = "no" ]; then
        PROMPT_COMMAND=("__powerbash_set_ps1 $1" "${PROMPT_COMMAND[@]}")
      fi
    else
      case "${PROMPT_COMMAND}" in
        *__powerbash_set_ps1*)
          # replace our existing entry in place, keeping its position
          local head="${PROMPT_COMMAND%%__powerbash_set_ps1 *}"
          local tail="${PROMPT_COMMAND#*__powerbash_set_ps1 }"
          # drop the mode token that follows, so it is replaced not prefixed
          case "$tail" in
            system*) tail="${tail#system}" ;;
            off*)    tail="${tail#off}" ;;
            on*)     tail="${tail#on}" ;;
          esac
          PROMPT_COMMAND="${head}__powerbash_set_ps1 $1${tail}"
          ;;
        *) PROMPT_COMMAND="__powerbash_set_ps1 $1;${PROMPT_COMMAND}" ;;
      esac
    fi
  }
}

# save system PS1
[ -z "$POWERBASH_SYSTEM_PS1" ] && POWERBASH_SYSTEM_PS1=$PS1

# define everything
__powerbash
unset -f __powerbash

# load saved configuration, then fill in anything it did not set
POWERBASH_CONFIG="${POWERBASH_CONFIG:-$HOME/.config/powerbashrc}"
__powerbash_config load
__powerbash_defaults

# start powerbash
__powerbash_set_prompt_command on

# enable auto completion
complete -F __powerbash_complete powerbash
