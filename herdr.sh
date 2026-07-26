#!/usr/bin/env bash

set -euo pipefail

# ==========================================
# Requirements
# ==========================================

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required"
    exit 1
fi

if ! command -v herdr >/dev/null 2>&1; then
    echo "Error: herdr is required"
    exit 1
fi


# ==========================================
# Herdr session/workspace configuration
# ==========================================

# Generally should never change. This is hardcoded in my bashrc and zshrc
SESSION_NAME="My"
# 1st Workspace on the left panel
WORKSPACE_NAME="Custom"


# ==========================================
# Tab definitions
# ==========================================

declare -A TAB_ROUTER=(
    [tab_name]="router"

    [ssh_remote]=true
    [ssh_remote_host]="192.168.22.199"
    [ssh_remote_port]="22"
    [ssh_remote_user]="duster"

    [ssh_remote_use_password]=true
    [ssh_remote_password]="duster"

    [initial_command]="htop"
)


declare -A TAB_LOCAL=(
    [tab_name]="local"

    [ssh_remote]=false
    [ssh_remote_host]=""
    [ssh_remote_port]=""
    [ssh_remote_user]=""

    [ssh_remote_use_password]=false
    [ssh_remote_password]=""

    [initial_command]="cat ~/.bashrc"
)


# Add/remove tabs here
TABS=(
    TAB_ROUTER
    TAB_LOCAL
)


# ==========================================
# Helpers
# ==========================================

# Session Handling
ensure_session() {
    if herdr session list | grep -q "^${SESSION_NAME}[[:space:]]"; then
        echo "Herdr session exists: $SESSION_NAME"
    else
        echo
        echo "Herdr session '$SESSION_NAME' does not exist."
        echo "Create it by attaching:"
        echo
        echo "  herdr session attach $SESSION_NAME"
        echo
        exit 1
    fi
}

get_workspace() {
    WORKSPACE_JSON=$(herdr workspace list)

    WORKSPACE_ID=$(echo "$WORKSPACE_JSON" | jq -r \
        '.result.workspaces[0].workspace_id')

    if [[ -z "$WORKSPACE_ID" || "$WORKSPACE_ID" == "null" ]]; then
        echo "Failed to find existing workspace"
        echo "$WORKSPACE_JSON"
        exit 1
    fi

    echo "Using workspace: $WORKSPACE_ID"
}


rename_workspace() {
    echo "Renaming workspace to: $WORKSPACE_NAME"

    herdr workspace rename \
        "$WORKSPACE_ID" \
        "$WORKSPACE_NAME"
}


build_command() {
    local -n tab=$1

    local cmd=""

    if [[ "${tab[ssh_remote]}" == "true" ]]; then

        if [[ "${tab[ssh_remote_use_password]}" == "true" ]]; then
            cmd="sshpass -p '${tab[ssh_remote_password]}' ssh"
        else
            cmd="ssh"
        fi

        cmd+=" -t"
        cmd+=" -p ${tab[ssh_remote_port]}"
        cmd+=" ${tab[ssh_remote_user]}@${tab[ssh_remote_host]}"

        if [[ -n "${tab[initial_command]}" ]]; then
            cmd+=" '${tab[initial_command]}; exec bash -i'"
        fi

    else

        if [[ -n "${tab[initial_command]}" ]]; then
            cmd="${tab[initial_command]}"
        fi

    fi

    echo "$cmd"
}


create_tab() {
    local -n tab=$1

    echo
    echo "Creating tab: ${tab[tab_name]}"

    TAB_RESULT=$(herdr tab create \
        --workspace "$WORKSPACE_ID" \
        --label "${tab[tab_name]}" \
        --no-focus)

    PANE_ID=$(echo "$TAB_RESULT" | jq -r \
        '.result.root_pane.pane_id')

    if [[ -z "$PANE_ID" || "$PANE_ID" == "null" ]]; then
        echo "Failed to get pane ID"
        echo "$TAB_RESULT"
        exit 1
    fi

    COMMAND=$(build_command "$1")

    echo "Pane: $PANE_ID"
    echo "Command: $COMMAND"

    if [[ -n "$COMMAND" ]]; then
        herdr pane run "$PANE_ID" "$COMMAND"
    fi
}


# ==========================================
# Main
# ==========================================

echo "Checking Herdr session: $SESSION_NAME"

ensure_session


echo "Finding existing workspace"

get_workspace


rename_workspace


for tab_config in "${TABS[@]}"; do
    create_tab "$tab_config"
done


echo
echo "Done."
