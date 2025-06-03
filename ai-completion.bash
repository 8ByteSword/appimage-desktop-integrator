#!/bin/bash

_ai_completion() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    local commands="status find install list remove update logs desktop help"
    
    # First argument - show commands
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
        # Also complete .AppImage files
        COMPREPLY+=( $(compgen -f -X '!*.AppImage' -- ${cur}) )
        return 0
    fi
    
    # Command-specific completions
    case "${COMP_WORDS[1]}" in
        install|add)
            # Complete with .AppImage files
            COMPREPLY=( $(compgen -f -X '!*.AppImage' -- ${cur}) )
            ;;
        remove|uninstall|rm|logs|log|update)
            # Complete with installed AppImage names
            if [ $COMP_CWORD -eq 2 ]; then
                local installed=""
                local update_dir="$HOME/.local/share/applications"
                
                for desktop_file in "$update_dir"/*.desktop; do
                    if [ -f "$desktop_file" ] && grep -q "\.AppImage" "$desktop_file" 2>/dev/null; then
                        name=$(grep "^Name=" "$desktop_file" | cut -d'=' -f2)
                        installed="$installed $name"
                    fi
                done
                
                COMPREPLY=( $(compgen -W "${installed}" -- ${cur}) )
            fi
            ;;
        *)
            # Default to files
            COMPREPLY=( $(compgen -f -- ${cur}) )
            ;;
    esac
}

# Register completion for both 'ai' and 'install_appimages'
complete -F _ai_completion ai
complete -F _ai_completion install_appimages