#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}Installing workspace tool...${NC}"
echo ""

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

missing_deps=()

if ! command -v git &> /dev/null; then
    missing_deps+=("git")
fi

if ! command -v tmux &> /dev/null; then
    missing_deps+=("tmux")
fi

if ! command -v overmind &> /dev/null; then
    missing_deps+=("overmind")
fi

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo -e "${RED}Missing dependencies:${NC}"
    for dep in "${missing_deps[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Install them first, then re-run this script."
    exit 1
fi

echo -e "  All dependencies found."
echo ""

# Create ~/.local/bin if needed
mkdir -p "$HOME/.local/bin"

# Copy the script
echo -e "${YELLOW}Installing workspace script...${NC}"
cp "$SCRIPT_DIR/workspace" "$HOME/.local/bin/workspace"
chmod +x "$HOME/.local/bin/workspace"
echo -e "  Installed to ~/.local/bin/workspace"

# Install shell completions
echo -e "${YELLOW}Installing shell completions...${NC}"

# Detect shell and install appropriate completion
current_shell=$(basename "$SHELL")

if [[ "$current_shell" == "zsh" ]]; then
    # Install zsh completion
    zsh_comp_dir="${HOME}/.zsh/completions"
    mkdir -p "$zsh_comp_dir"
    cp "$SCRIPT_DIR/workspace.completion.zsh" "$zsh_comp_dir/_workspace"
    echo -e "  Installed zsh completion to $zsh_comp_dir/_workspace"

    # Check if the completion dir is in fpath
    if ! zsh -c "echo \$fpath" 2>/dev/null | grep -q "$zsh_comp_dir"; then
        echo ""
        echo -e "  ${YELLOW}Add this to your ~/.zshrc (before compinit):${NC}"
        echo ""
        echo "    fpath=(~/.zsh/completions \$fpath)"
        echo "    autoload -Uz compinit && compinit"
        echo ""
    fi
elif [[ "$current_shell" == "bash" ]]; then
    # Install bash completion
    bash_comp_dir="${HOME}/.local/share/bash-completion/completions"
    mkdir -p "$bash_comp_dir"
    cp "$SCRIPT_DIR/workspace.completion.bash" "$bash_comp_dir/workspace"
    echo -e "  Installed bash completion to $bash_comp_dir/workspace"
fi

# Create config if it doesn't exist
if [[ ! -f "$HOME/.workspaces.yml" ]]; then
    echo -e "${YELLOW}Creating config file...${NC}"
    cp "$SCRIPT_DIR/workspaces.yml.example" "$HOME/.workspaces.yml"
    echo -e "  Created ~/.workspaces.yml"
    echo -e "  ${YELLOW}Edit this file to add your projects.${NC}"
else
    echo -e "${YELLOW}Config file already exists at ~/.workspaces.yml${NC}"
fi

# Check PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo -e "${YELLOW}Note: ~/.local/bin is not in your PATH.${NC}"
    echo "Add this to your shell config (~/.zshrc or ~/.bashrc):"
    echo ""
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo ""
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Usage:"
echo "  workspace new <project> <feature>     Create a new workspace"
echo "  workspace delete <project> <feature>  Delete a workspace"
echo "  workspace list [project]              List workspaces"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.workspaces.yml to configure your projects"
echo "  2. Optionally create Procfile.workspace.template in each project"
echo ""
