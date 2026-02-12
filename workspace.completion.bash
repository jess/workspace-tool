_workspace_completions() {
    local cur prev words cword
    _init_completion || return

    local commands="new pull resume delete list"
    local config_file="$HOME/.workspaces.yml"

    # Complete subcommand
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return
    fi

    local command="${words[1]}"

    # Complete project name
    if [[ $cword -eq 2 ]]; then
        local projects
        projects=$(awk '/^  [a-zA-Z_-]+:$/ { proj = $1; gsub(/:$/, "", proj); print proj }' "$config_file" 2>/dev/null)
        COMPREPLY=($(compgen -W "$projects" -- "$cur"))
        return
    fi

    # Complete feature/branch name for resume and delete
    if [[ $cword -eq 3 ]] && [[ "$command" == "resume" || "$command" == "delete" ]]; then
        local project="${words[2]}"
        local project_path worktree_dir

        project_path=$(awk -v proj="$project" '
            /^  [a-zA-Z_-]+:$/ { current = $1; gsub(/:$/, "", current) }
            current == proj && $1 == "path:" {
                val = $0; sub(/^[^:]+:[ \t]*/, "", val); sub(/[ \t]*#.*$/, "", val); print val; exit
            }
        ' "$config_file" 2>/dev/null)
        project_path="${project_path/#\~/$HOME}"

        worktree_dir=$(awk -v proj="$project" '
            /^  [a-zA-Z_-]+:$/ { current = $1; gsub(/:$/, "", current) }
            current == proj && $1 == "worktree_dir:" {
                val = $0; sub(/^[^:]+:[ \t]*/, "", val); sub(/[ \t]*#.*$/, "", val); print val; exit
            }
        ' "$config_file" 2>/dev/null)
        worktree_dir="${worktree_dir/#\~/$HOME}"

        if [[ -n "$project_path" ]]; then
            local features
            features=$(git -C "$project_path" worktree list 2>/dev/null \
                | grep -v "^${project_path} " \
                | awk '{print $1}' \
                | while read -r p; do basename "$p"; done)
            COMPREPLY=($(compgen -W "$features" -- "$cur"))
        fi
        return
    fi
}

complete -F _workspace_completions workspace
