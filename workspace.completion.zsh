#compdef workspace

_workspace() {
    local config_file="$HOME/.workspaces.yml"
    local commands=(
        'new:Create a new workspace (new branch off master)'
        'pull:Pull a remote branch into a new workspace'
        'resume:Resume an existing workspace'
        'resume-all:Resume all workspaces (useful after reboot)'
        'delete:Delete a workspace'
        'list:List all workspaces'
        'redis:Show Redis DB allocations'
    )

    _arguments -C \
        '1:command:->command' \
        '2:project:->project' \
        '3:feature:->feature' \
        && return

    case "$state" in
        command)
            _describe 'command' commands
            ;;
        project)
            local projects
            projects=($(awk '/^  [a-zA-Z_-]+:$/ { proj = $1; gsub(/:$/, "", proj); print proj }' "$config_file" 2>/dev/null))
            _describe 'project' projects
            ;;
        feature)
            local command="${words[2]}"
            if [[ "$command" == "resume" || "$command" == "delete" ]]; then
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
                    _describe 'feature' features
                fi
            fi
            ;;
    esac
}

_workspace "$@"
