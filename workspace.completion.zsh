#compdef workspace

_workspace() {
    local config_file="$HOME/.workspaces.yml"
    local commands=(
        'new:Create a new workspace (new branch off master)'
        'pull:Pull a remote branch into a new workspace'
        'resume:Resume workspace(s) (--all for everything)'
        'stop:Stop workspace(s) without deleting'
        'delete:Delete a workspace'
        'info:Show info about the current workspace'
        'list:List all workspaces'
        'ports:Show all port and Redis allocations'
    )

    _arguments -C \
        '1:command:->command' \
        '*:args:->args' \
        && return

    case "$state" in
        command)
            _describe 'command' commands
            ;;
        args)
            local command="${words[2]}"
            case "$command" in
                resume)
                    # Complete --all or project name at position 2
                    if [[ $CURRENT -eq 3 ]]; then
                        local projects
                        projects=($(awk '/^  [a-zA-Z_-]+:$/ { proj = $1; gsub(/:$/, "", proj); print proj }' "$config_file" 2>/dev/null))
                        local options=("--all:Resume all workspaces" "${(@)projects}")
                        _describe 'project or flag' options
                        return
                    fi
                    ;;
                list)
                    local flags=('--pr:Show PR status' '--running:Show only active workspaces')
                    local projects
                    projects=($(awk '/^  [a-zA-Z_-]+:$/ { proj = $1; gsub(/:$/, "", proj); print proj }' "$config_file" 2>/dev/null))
                    local options=("${(@)flags}" "${(@)projects}")
                    _describe 'project or flag' options
                    return
                    ;;
            esac

            # Fall through to project completion at position 2
            if [[ $CURRENT -eq 3 ]]; then
                local projects
                projects=($(awk '/^  [a-zA-Z_-]+:$/ { proj = $1; gsub(/:$/, "", proj); print proj }' "$config_file" 2>/dev/null))
                _describe 'project' projects
                return
            fi

            # Feature completion at position 3
            if [[ $CURRENT -eq 4 && ("$command" == "resume" || "$command" == "stop" || "$command" == "delete") ]]; then
                local project="${words[3]}"
                local project_path

                project_path=$(awk -v proj="$project" '
                    /^  [a-zA-Z_-]+:$/ { current = $1; gsub(/:$/, "", current) }
                    current == proj && $1 == "path:" {
                        val = $0; sub(/^[^:]+:[ \t]*/, "", val); sub(/[ \t]*#.*$/, "", val); print val; exit
                    }
                ' "$config_file" 2>/dev/null)
                project_path="${project_path/#\~/$HOME}"

                if [[ -n "$project_path" ]]; then
                    local features
                    features=($(git -C "$project_path" worktree list 2>/dev/null \
                        | grep -v "^${project_path} " \
                        | awk '{print $1}' \
                        | while read -r p; do basename "$p"; done))
                    # Include main if initialized
                    if [[ "$command" != "delete" && -f "$project_path/Procfile.workspace" ]]; then
                        features+=("main")
                    fi
                    _describe 'feature' features
                fi
            fi
            ;;
    esac
}

_workspace "$@"
