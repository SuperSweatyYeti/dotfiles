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

VPS_PROXY_IP=$(dig +short @1.1.1.1 palworld.sweatyyeti.xyz | head -n1)

# [split_direction] options: right | down

declare -A TAB3=(
    [tab_name]="VPS Proxy"
    [ssh_remote]=true
    [ssh_remote_host]="${VPS_PROXY_IP}"
    [ssh_remote_port]="22"
    [ssh_remote_user]="duster"
    [ssh_remote_use_password]=false
    [ssh_remote_password]=""
    [initial_command]=""

    [enable_split]=true
    [split_direction]="right"
    [split_ssh_remote]=false
    [split_ssh_remote_host]=""
    [split_ssh_remote_port]="22"
    [split_ssh_remote_user]=""
    [split_ssh_remote_use_password]=false
    [split_ssh_remote_password]=""
    [split_initial_command]="cat /etc/hosts"
)

declare -A TAB2=(
    [tab_name]="GameServer"

    [ssh_remote]=true
    [ssh_remote_host]="192.168.22.199"
    [ssh_remote_port]="22"
    [ssh_remote_user]="duster"

    [ssh_remote_use_password]=true
    [ssh_remote_password]="duster"

    [initial_command]="cd ~/docker"

    [enable_split]=false
    [split_direction]="right"
    [split_ssh_remote]=false
    [split_ssh_remote_host]=""
    [split_ssh_remote_port]="22"
    [split_ssh_remote_user]=""
    [split_ssh_remote_use_password]=false
    [split_ssh_remote_password]=""
    [split_initial_command]=""
)


declare -A TAB1=(
    [tab_name]="Local"

    [ssh_remote]=false
    [ssh_remote_host]=""
    [ssh_remote_port]=""
    [ssh_remote_user]=""

    [ssh_remote_use_password]=false
    [ssh_remote_password]=""

    [initial_command]="cat ~/.bashrc"

    [enable_split]=false
    [split_direction]="right"
    [split_ssh_remote]=false
    [split_ssh_remote_host]=""
    [split_ssh_remote_port]="22"
    [split_ssh_remote_user]=""
    [split_ssh_remote_use_password]=false
    [split_ssh_remote_password]=""
    [split_initial_command]=""
)


# Add/remove tabs here
# Tabs created in order
TABS=(
    TAB1
    TAB2
    TAB3
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

    if [[ "${tab[enable_split]}" == "true" ]]; then
        echo "Splitting pane: ${tab[split_direction]}"
        SPLIT_RESULT=$(herdr pane split "$PANE_ID" --direction "${tab[split_direction]}")
        SPLIT_PANE_ID=$(echo "$SPLIT_RESULT" | jq -r '.result.pane.pane_id')

        if [[ -z "$SPLIT_PANE_ID" || "$SPLIT_PANE_ID" == "null" ]]; then
            echo "Failed to get split pane ID"
            echo "$SPLIT_RESULT"
            exit 1
        fi

        local split_cmd=""
        if [[ "${tab[split_ssh_remote]}" == "true" ]]; then
            if [[ "${tab[split_ssh_remote_use_password]}" == "true" ]]; then
                split_cmd="sshpass -p '${tab[split_ssh_remote_password]}' ssh"
            else
                split_cmd="ssh"
            fi
            split_cmd+=" -t"
            split_cmd+=" -p ${tab[split_ssh_remote_port]}"
            split_cmd+=" ${tab[split_ssh_remote_user]}@${tab[split_ssh_remote_host]}"
            if [[ -n "${tab[split_initial_command]}" ]]; then
                split_cmd+=" '${tab[split_initial_command]}; exec bash -i'"
            fi
        else
            if [[ -n "${tab[split_initial_command]}" ]]; then
                split_cmd="${tab[split_initial_command]}"
            fi
        fi

        echo "Split Pane: $SPLIT_PANE_ID"
        echo "Split Command: $split_cmd"

        if [[ -n "$split_cmd" ]]; then
            herdr pane run "$SPLIT_PANE_ID" "$split_cmd"
        fi
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

