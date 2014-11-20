#!/usr/bin/env bash

#
#  Completion for bash-powerline:
#
_prompt_complete() 
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="on off system reload path"
 
    case "${prev}" in
        on)
            COMPREPLY=( $(compgen ${cur}) )
            return 0
            ;;
        off)
            COMPREPLY=( $(compgen ${cur}) )
            return 0
            ;;
        system)
            COMPREPLY=( $(compgen ${cur}) )
            return 0
            ;;
        reload)
            COMPREPLY=( $(compgen ${cur}) )
            return 0
            ;;
        path)
            COMPREPLY=( $(compgen -W "on off short-path short-directory" -- ${cur}) )
            return 0
            ;;
        "short-path")
            COMPREPLY=( $(compgen -W "add subtract" -- ${cur}) )
            return 0
            ;;
        *)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
    esac

}
complete -F _prompt_complete prompt
