#!/usr/bin/env bash
# nmcli-try.sh — configure NetworkManager connections with automatic rollback
#
# Replicates "netplan try" functionality: applies a configuration, then waits
# for confirmation before committing. Times out and rolls back automatically.
#
# USAGE:
#   nmcli-try.sh [CONNECTION OPTIONS] [--timeout-seconds N] [--dry-run]
#   nmcli-try.sh --list
#   nmcli-try.sh --show NAME
#   nmcli-try.sh --rollback NAME
#   nmcli-try.sh --connection-restart NAME
#   nmcli-try.sh --examples
#
# SETUP COMPLETIONS (run once):
#   source nmcli-try.sh --setup-completions

# Do NOT use set -e — we handle errors explicitly to avoid silent exits
set -uo pipefail

MIN_BASH_VERSION_MAJOR=4
MIN_BASH_VERSION_MINOR=0

# Require Bash 4.0+
CURRENT_BASH_VERSION_MAJOR=${BASH_VERSINFO[0]}

if  [[ ${CURRENT_BASH_VERSION_MAJOR} -lt ${MIN_BASH_VERSION_MAJOR} ]]; then
    echo "Error: Bash ${MIN_BASH_VERSION_MAJOR}.${MIN_BASH_VERSION_MINOR} or newer is required. Found: ${BASH_VERSION}" >&2
    exit 1
fi

# =============================================================================
# COMPLETION SETUP
# =============================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    _nmcli_try_complete() {
        local cur prev
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]:-}"
        COMPREPLY=()

        local all_opts="--connection-name --connection-type --ssid --wifi-password
            --wifi-security --ipv4-method --ipv4-address --ipv4-gateway --ipv4-dns
            --ipv6-method --ipv6-address --ipv6-gateway --ipv6-dns
            --interface --autoconnect --metric --vlan-id --vlan-parent
            --clear-ipv4-address --clear-ipv4-gateway --clear-ipv4-dns
            --clear-ipv6-address --clear-ipv6-gateway --clear-ipv6-dns
            --clear-ssid --clear-wifi-security --clear-interface
            --clear-metric --clear-autoconnect
            --timeout-seconds --rollback --show --list --connection-restart
            --dry-run --verbose --examples --help"

        local suggestions=""
        case "$prev" in
            --connection-type) suggestions="wifi ethernet vpn bridge bond vlan dummy" ;;
            --wifi-security)   suggestions="wpa-psk wpa-eap none" ;;
            --ipv4-method)     suggestions="auto manual disabled link-local" ;;
            --ipv6-method)     suggestions="auto manual disabled ignore link-local" ;;
            --autoconnect)     suggestions="yes no" ;;
            --timeout-seconds) suggestions="30 60 90 120 180 300" ;;
            --interface|--vlan-parent)
                suggestions="$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | tr '\n' ' ')" ;;
            --connection-name|--rollback|--show|--connection-restart)
                suggestions="$(nmcli -t -f NAME con show 2>/dev/null | tr '\n' ' ')" ;;
            *) suggestions="$all_opts" ;;
        esac

        COMPREPLY=( $(compgen -W "$suggestions" -- "$cur") )
    }

    complete -F _nmcli_try_complete nmcli-try.sh
    complete -F _nmcli_try_complete nmcli-try
    complete -F _nmcli_try_complete ./nmcli-try.sh
    [[ -f /usr/local/bin/nmcli-try ]] && complete -F _nmcli_try_complete /usr/local/bin/nmcli-try
    return 0
fi

if [[ "${1:-}" == "--setup-completions" ]]; then
    SCRIPT_PATH="$(realpath "$0")"
    MARKER="nmcli_try_completions"
    SNIPPET="# $MARKER"$'\n'"source \"$SCRIPT_PATH\""
    if ! grep -qF "$MARKER" ~/.bashrc 2>/dev/null; then
        printf '\n%s\n' "$SNIPPET" >> ~/.bashrc
        echo "Completions registered. Run: source ~/.bashrc"
    else
        echo "Completions already registered in ~/.bashrc"
    fi
    exit 0
fi

# =============================================================================
# DEFAULTS
# =============================================================================

CONNECTION_NAME=""
CONNECTION_TYPE=""
SSID=""
WIFI_PASSWORD=""
WIFI_SECURITY=""
IPV4_METHOD=""
IPV4_ADDRESS=""
IPV4_GATEWAY=""
IPV4_DNS=""
IPV6_METHOD=""
IPV6_ADDRESS=""
IPV6_GATEWAY=""
IPV6_DNS=""
INTERFACE=""
AUTOCONNECT=""
METRIC=""
VLAN_ID=""
VLAN_PARENT=""

# Explicit clear flags — set to 1 by --clear-* args
CLEAR_IPV4_ADDRESS=0
CLEAR_IPV4_GATEWAY=0
CLEAR_IPV4_DNS=0
CLEAR_IPV6_ADDRESS=0
CLEAR_IPV6_GATEWAY=0
CLEAR_IPV6_DNS=0
CLEAR_SSID=0
CLEAR_WIFI_SECURITY=0
CLEAR_INTERFACE=0
CLEAR_METRIC=0
CLEAR_AUTOCONNECT=0

TIMEOUT=60
ROLLBACK_TARGET=""
SHOW_TARGET=""
RESTART_TARGET=""
LIST_MODE=0
DRY_RUN=0
VERBOSE=0

BACKUP_DIR="/tmp/nmcli-try-backup-$$"
CONNECTION_APPLIED=false

# Sentinel used internally to pass "clear this field" through the arg builder
readonly CLEAR="__CLEAR__"

# =============================================================================
# HELPERS
# =============================================================================

log()     { echo "[INFO]  $*"; }
warn()    { echo "[WARN]  $*" >&2; }
err()     { echo "[ERROR] $*" >&2; exit 1; }
verbose() { [[ $VERBOSE -eq 1 ]] && echo "[DEBUG] $*" >&2 || true; }
trace()   { [[ $VERBOSE -eq 1 ]] && echo "[TRACE] $(date '+%T') $*" >&2 || true; }

require_cmd()  { command -v "$1" &>/dev/null || err "Required command '$1' not found."; }
require_root() { [[ $EUID -eq 0 ]] || err "This script must be run as root. Try: sudo $0 $*"; }

is_valid_cidr() {
    local cidr="$1" ip prefix
    ip="${cidr%/*}"; prefix="${cidr#*/}"
    [[ "$cidr" == */* && "$prefix" =~ ^[0-9]+$ ]] || return 1
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        [[ $prefix -le 32 ]] || return 1
        local IFS='.'; read -ra o <<< "$ip"
        for oct in "${o[@]}"; do [[ $oct -le 255 ]] || return 1; done
        return 0
    fi
    [[ "$ip" =~ ^[0-9a-fA-F:]+$ && $prefix -le 128 ]] && return 0
    return 1
}

is_valid_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'; read -ra o <<< "$ip"
        for oct in "${o[@]}"; do [[ $oct -le 255 ]] || return 1; done
        return 0
    fi
    [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] && return 0
    return 1
}

is_valid_interface() { ip link show "$1" &>/dev/null; }

connection_exists() {
    trace "connection_exists: checking for '$1'"
    if nmcli -t -f NAME con show 2>/dev/null | grep -qxF "$1"; then
        trace "connection_exists: '$1' FOUND"
        return 0
    else
        trace "connection_exists: '$1' NOT FOUND"
        return 1
    fi
}

# =============================================================================
# PREFLIGHT
# =============================================================================

preflight() {
    trace "preflight: checking nmcli"
    require_cmd nmcli
    trace "preflight: checking ip"
    require_cmd ip
    trace "preflight: checking NetworkManager status"
    if ! nmcli general status &>/dev/null; then
        err "NetworkManager does not appear to be running. Start it with: systemctl start NetworkManager"
    fi
    verbose "Preflight checks passed."
}

# =============================================================================
# ROLLBACK / CLEANUP
# =============================================================================

do_rollback_on_exit() {
    echo ""
    trace "do_rollback_on_exit: CONNECTION_APPLIED=$CONNECTION_APPLIED"
    if [[ "$CONNECTION_APPLIED" != true ]]; then
        log "No connection was applied. Nothing to roll back."
        rm -rf "$BACKUP_DIR"
        return
    fi

    warn "Rolling back changes to '$CONNECTION_NAME'..."

    if [[ -n "$CONNECTION_NAME" ]]; then
        local conn_exists=0
        connection_exists "$CONNECTION_NAME" && conn_exists=1 || true
        trace "do_rollback_on_exit: conn_exists=$conn_exists"
        if [[ $conn_exists -eq 1 ]]; then
            nmcli connection delete "$CONNECTION_NAME" 2>/dev/null \
                && log "Removed connection '$CONNECTION_NAME'." \
                || warn "Could not remove '$CONNECTION_NAME' — remove it manually."
        fi
    fi

    if [[ -d "$BACKUP_DIR" && -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        local needs_restore=false
        for f in "$BACKUP_DIR"/*; do
            [[ -f "/etc/NetworkManager/system-connections/$(basename "$f")" ]] \
                || { needs_restore=true; break; }
        done
        trace "do_rollback_on_exit: needs_restore=$needs_restore"
        if [[ "$needs_restore" == true ]]; then
            cp -r "$BACKUP_DIR"/. /etc/NetworkManager/system-connections/
            chmod 600 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true
            nmcli connection reload
            log "Previous connections restored from backup."
        fi
    fi

    rm -rf "$BACKUP_DIR"
    log "Rollback complete."
}

do_connection_restart() {
    local name="$1"
    connection_exists "$name" || err "Connection '$name' not found."

    log "Restarting connection '$name'..."
    if nmcli connection show --active 2>/dev/null | grep -qF "$name"; then
        verbose "'$name' is active — bringing it down."
        nmcli connection down "$name" \
            && log "Connection '$name' brought down." \
            || warn "Could not bring down '$name' — attempting to bring it up anyway."
    else
        verbose "'$name' is not currently active — skipping down step."
    fi

    if nmcli connection up "$name"; then
        log "Connection '$name' is up."
    else
        err "Failed to bring up '$name'. Check: nmcli device status"
    fi
}

do_named_rollback() {
    local name="$1"
    local safe_name="${name//[^a-zA-Z0-9_-]/_}"
    local store="$HOME/.nmcli-try/backups"
    local latest
    latest=$(ls -t "${store}/${safe_name}__"*.snap 2>/dev/null | head -1 || true)
    [[ -n "$latest" ]] || err "No persistent backup found for '$name'. (Looked in $store)"

    warn "This will delete the current '$name' connection and restore from:"
    warn "  $latest"
    read -rp "Proceed? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log "Rollback aborted."; exit 0; }

    local conn_exists=0
    connection_exists "$name" && conn_exists=1 || true
    if [[ $conn_exists -eq 1 ]]; then
        nmcli connection delete "$name"
        log "Deleted current '$name'."
    fi

    local btype bipv4 bgateway bdns
    btype=$(   grep -m1 "^connection.type:"  "$latest" | awk '{print $2}' || true)
    bipv4=$(   grep -m1 "^ipv4.addresses:"   "$latest" | awk '{print $2}' || true)
    bgateway=$(grep -m1 "^ipv4.gateway:"     "$latest" | awk '{print $2}' || true)
    bdns=$(    grep -m1 "^ipv4.dns:"         "$latest" | awk '{print $2}' || true)

    local add_args=("con" "add" "type" "${btype:-ethernet}" "con-name" "$name")
    [[ -n "$bipv4"    ]] && add_args+=("ipv4.addresses" "$bipv4")
    [[ -n "$bgateway" ]] && add_args+=("ipv4.gateway"   "$bgateway")
    [[ -n "$bdns"     ]] && add_args+=("ipv4.dns"        "$bdns")

    nmcli "${add_args[@]}"
    log "Rollback of '$name' complete."
}

save_persistent_backup() {
    local name="$1"
    local store="$HOME/.nmcli-try/backups"
    local safe_name="${name//[^a-zA-Z0-9_-]/_}"
    local ts; ts="$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$store"
    local exists=0
    connection_exists "$name" && exists=1 || true
    trace "save_persistent_backup: exists=$exists for '$name'"
    if [[ $exists -eq 0 ]]; then
        verbose "No existing connection '$name' to back up persistently."
        return 0
    fi
    local bfile="${store}/${safe_name}__${ts}.snap"
    nmcli -t con show "$name" > "$bfile" 2>/dev/null || true
    verbose "Persistent backup saved: $bfile"
}

# =============================================================================
# EXAMPLES
# =============================================================================

show_examples() {
    cat <<'EOF'
nmcli-try.sh — example usage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSPECT ─────────────────────────────────────────────────────────────────────

  # List all connections
  nmcli-try.sh --list

  # Show full details of a specific connection
  nmcli-try.sh --show "CL3DMA"

  # Preview what a change would do without applying it
  nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address 192.168.1.50/24 \
               --dry-run

  # Debug any command by adding --verbose
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address 192.168.1.50/24 \
               --verbose --dry-run

CREATE — WIFI ───────────────────────────────────────────────────────────────

  # New WPA2 WiFi connection (DHCP, auto IP)
  sudo nmcli-try.sh --connection-name "Home" \
               --connection-type wifi \
               --ssid "MyNetwork" \
               --wifi-password "mysecretpassword"

  # New WPA2 WiFi connection with a static IP
  sudo nmcli-try.sh --connection-name "Home" \
               --connection-type wifi \
               --ssid "MyNetwork" \
               --wifi-password "mysecretpassword" \
               --ipv4-address 192.168.0.20/24 \
               --ipv4-gateway 192.168.0.1 \
               --ipv4-dns "8.8.8.8,8.8.4.4"

  # New WPA2 WiFi bound to a specific wireless interface
  sudo nmcli-try.sh --connection-name "Home" \
               --connection-type wifi \
               --interface wlan0 \
               --ssid "MyNetwork" \
               --wifi-password "mysecretpassword"

  # New open (no password) WiFi connection
  sudo nmcli-try.sh --connection-name "CafeWiFi" \
               --connection-type wifi \
               --ssid "FreeWiFi" \
               --wifi-security none \
               --ipv4-method auto

  # New WPA2-Enterprise (802.1X) WiFi connection
  sudo nmcli-try.sh --connection-name "Corporate" \
               --connection-type wifi \
               --ssid "CorpNet" \
               --wifi-security wpa-eap \
               --ipv4-method auto

  # New hidden network WiFi connection with static IP
  sudo nmcli-try.sh --connection-name "HiddenNet" \
               --connection-type wifi \
               --ssid "HiddenSSID" \
               --wifi-password "secretpassword" \
               --ipv4-address 10.0.0.100/24 \
               --ipv4-gateway 10.0.0.1 \
               --ipv4-dns "1.1.1.1,1.0.0.1"

  # New WiFi connection with IPv6 disabled
  sudo nmcli-try.sh --connection-name "Home" \
               --connection-type wifi \
               --ssid "MyNetwork" \
               --wifi-password "mysecretpassword" \
               --ipv4-method auto \
               --ipv6-method disabled

CREATE — ETHERNET ───────────────────────────────────────────────────────────

  # New DHCP Ethernet connection
  sudo nmcli-try.sh --connection-name "Wired" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-method auto

  # New static Ethernet connection
  sudo nmcli-try.sh --connection-name "Office" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-address 10.0.0.50/24 \
               --ipv4-gateway 10.0.0.1 \
               --ipv4-dns "10.0.0.1,8.8.8.8"

  # New static Ethernet with IPv6 disabled
  sudo nmcli-try.sh --connection-name "Office" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-address 192.168.1.50/24 \
               --ipv4-gateway 192.168.1.1 \
               --ipv4-dns "8.8.8.8,8.8.4.4" \
               --ipv6-method disabled

  # New static Ethernet with multiple DNS servers and autoconnect off
  sudo nmcli-try.sh --connection-name "Lab" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-address 172.16.0.10/16 \
               --ipv4-gateway 172.16.0.1 \
               --ipv4-dns "172.16.0.1,8.8.8.8,1.1.1.1" \
               --autoconnect no

  # New DHCP Ethernet that does not autoconnect
  sudo nmcli-try.sh --connection-name "Temp" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-method auto \
               --autoconnect no

CREATE — IPv6 ───────────────────────────────────────────────────────────────

  # New Ethernet with static IPv6 only (IPv4 disabled)
  sudo nmcli-try.sh --connection-name "IPv6Office" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-method disabled \
               --ipv6-method manual \
               --ipv6-address "2001:db8::100/64" \
               --ipv6-gateway "2001:db8::1" \
               --ipv6-dns "2001:4860:4860::8888,2001:4860:4860::8844"

  # New dual-stack connection (static IPv4 + SLAAC IPv6)
  sudo nmcli-try.sh --connection-name "DualStack" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-address 192.168.1.50/24 \
               --ipv4-gateway 192.168.1.1 \
               --ipv4-dns "8.8.8.8,8.8.4.4" \
               --ipv6-method auto

  # New dual-stack connection (static IPv4 + static IPv6)
  sudo nmcli-try.sh --connection-name "DualStackStatic" \
               --connection-type ethernet \
               --interface eth0 \
               --ipv4-address 192.168.1.50/24 \
               --ipv4-gateway 192.168.1.1 \
               --ipv6-address "2001:db8::50/64" \
               --ipv6-gateway "2001:db8::1" \
               --ipv6-dns "2001:4860:4860::8888"

CREATE — VLAN ───────────────────────────────────────────────────────────────

  # New VLAN connection using DHCP
  sudo nmcli-try.sh --connection-name "VLAN100" \
               --connection-type vlan \
               --vlan-id 100 \
               --vlan-parent eth0 \
               --ipv4-method auto

  # New VLAN connection with a static IP
  sudo nmcli-try.sh --connection-name "VLAN200" \
               --connection-type vlan \
               --vlan-id 200 \
               --vlan-parent eth0 \
               --ipv4-address 10.20.0.5/24 \
               --ipv4-gateway 10.20.0.1 \
               --ipv4-dns "10.20.0.1,8.8.8.8"

EDIT — IPv4 ─────────────────────────────────────────────────────────────────

  # Change only the IP address (--ipv4-method manual is inferred)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address 192.168.1.50/24

  # Assign multiple static IPv4 addresses (comma-separated)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address "192.168.1.50/24,10.0.0.5/24"

  # Change IP, gateway and DNS in one shot
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address 192.168.1.50/24 \
               --ipv4-gateway 192.168.1.1 \
               --ipv4-dns "8.8.8.8,1.1.1.1"

  # Change only the DNS servers
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-dns "1.1.1.1,1.0.0.1"

  # Change only the default gateway
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-gateway 192.168.1.254

  # Switch from static IP to DHCP (automatically clears address, gateway, dns)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-method auto

  # Switch to DHCP but keep a specific DNS server pinned
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-method auto \
               --ipv4-dns "1.1.1.1"

  # Set a route metric (lower = preferred when multiple connections are active)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --metric 100

EDIT — IPv6 ─────────────────────────────────────────────────────────────────

  # Add a static IPv6 address to an existing connection
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv6-address "2001:db8::50/64" \
               --ipv6-gateway "2001:db8::1"

  # Switch IPv6 to SLAAC (auto-configure, clears static address/gateway/dns)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv6-method auto

  # Disable IPv6 entirely on an existing connection
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv6-method disabled

  # Change IPv6 DNS servers
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv6-dns "2001:4860:4860::8888,2001:4860:4860::8844"

EDIT — WIFI ─────────────────────────────────────────────────────────────────

  # Change the WiFi password on an existing connection
  sudo nmcli-try.sh --connection-name "Home" \
               --wifi-password "newpassword"

  # Change the SSID and password together
  sudo nmcli-try.sh --connection-name "Home" \
               --ssid "NewNetworkName" \
               --wifi-password "newpassword"

  # Remove WiFi security (switch to open network)
  sudo nmcli-try.sh --connection-name "Home" \
               --wifi-security none

  # Update WiFi password and switch to a static IP at the same time
  sudo nmcli-try.sh --connection-name "Home" \
               --wifi-password "newpassword" \
               --ipv4-address 192.168.0.50/24 \
               --ipv4-gateway 192.168.0.1

EDIT — GENERAL ──────────────────────────────────────────────────────────────

  # Bind an existing connection to a specific interface
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --interface eth0

  # Enable autoconnect on a connection
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --autoconnect yes

  # Disable autoconnect on a connection
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --autoconnect no

  # Change interface binding and disable autoconnect together
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --interface eth1 \
               --autoconnect no

CLEAR — REMOVE INDIVIDUAL PROPERTIES ───────────────────────────────────────

  # Remove a static IPv4 address (without changing the method)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv4-address

  # Remove the IPv4 gateway
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv4-gateway

  # Remove all IPv4 DNS servers
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv4-dns

  # Remove a static IPv6 address
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv6-address

  # Remove the IPv6 gateway
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv6-gateway

  # Remove all IPv6 DNS servers
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv6-dns

  # Remove the interface binding (let NM choose)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-interface

  # Remove the route metric (revert to default)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-metric

  # Remove the autoconnect override (revert to NM default)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-autoconnect

  # Remove WiFi security entirely
  sudo nmcli-try.sh --connection-name "Home" \
               --clear-wifi-security

  # Clear multiple properties at once
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --clear-ipv4-address \
               --clear-ipv4-gateway \
               --clear-ipv4-dns

  # Switch to DHCP and clear metric at the same time
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-method auto \
               --clear-metric

TIMEOUT ─────────────────────────────────────────────────────────────────────

  # Use a custom timeout (default is 60 seconds)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address 192.168.1.50/24 \
               --timeout-seconds 120

  # Give yourself extra time over SSH to verify connectivity before confirming
  # (if you lose the connection, it will roll back automatically after 300s)
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-address 10.0.0.5/24 \
               --ipv4-gateway 10.0.0.1 \
               --timeout-seconds 300

  # Minimal timeout — apply and confirm quickly
  sudo nmcli-try.sh --connection-name "CL3DMA" \
               --ipv4-dns "1.1.1.1" \
               --timeout-seconds 10

RESTART ─────────────────────────────────────────────────────────────────────

  # Bring a connection down and back up (refreshes DHCP lease, re-auths, etc.)
  sudo nmcli-try.sh --connection-restart "CL3DMA"

  # Restart a WiFi connection to reconnect to the access point
  sudo nmcli-try.sh --connection-restart "Home"

ROLLBACK ────────────────────────────────────────────────────────────────────

  # Restore a connection to its last saved state (from persistent backup)
  sudo nmcli-try.sh --rollback "CL3DMA"

  # Tip: every successful apply saves a timestamped backup to:
  #   ~/.nmcli-try/backups/
  # You can see all backups for a connection with:
  #   ls ~/.nmcli-try/backups/ | grep CL3DMA

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# =============================================================================
# USAGE
# =============================================================================

usage() {
    cat <<EOF
nmcli-try.sh — configure NetworkManager connections with automatic rollback

USAGE:
  nmcli-try.sh [CONNECTION OPTIONS] [--timeout-seconds N] [--dry-run] [-v]
  nmcli-try.sh --list
  nmcli-try.sh --show NAME
  nmcli-try.sh --rollback NAME
  nmcli-try.sh --connection-restart NAME
  nmcli-try.sh --examples

CONNECTION IDENTITY:
  --connection-name NAME      Name of the connection (required for edits)
  --connection-type TYPE      wifi | ethernet | vpn | bridge | bond | vlan | dummy

WIFI:
  --ssid SSID                 WiFi network name
  --wifi-password PASSWORD    WiFi passphrase
  --wifi-security TYPE        wpa-psk | wpa-eap | none

IPv4:
  --ipv4-method METHOD        auto | manual | disabled | link-local
  --ipv4-address CIDR[,CIDR]  e.g. 192.168.1.10/24 or 192.168.1.10/24,10.0.0.5/24  (implies manual)
  --ipv4-gateway IP           Default gateway
  --ipv4-dns IPs              Comma-separated DNS servers

IPv6:
  --ipv6-method METHOD        auto | manual | disabled | ignore | link-local
  --ipv6-address CIDR[,CIDR]  e.g. fd00::1/64 or fd00::1/64,2001:db8::1/64  (implies manual)
  --ipv6-gateway IP           Default IPv6 gateway
  --ipv6-dns IPs              Comma-separated IPv6 DNS servers

VLAN (requires --connection-type vlan):
  --vlan-id ID                VLAN ID 0–4094
  --vlan-parent IFACE         Parent interface

GENERAL:
  --interface IFACE           Bind to a specific network interface
  --autoconnect yes|no        Enable/disable autoconnect
  --metric N                  Route metric

CLEAR (remove a property entirely):
  --clear-ipv4-address        Remove static IPv4 address
  --clear-ipv4-gateway        Remove IPv4 gateway
  --clear-ipv4-dns            Remove all IPv4 DNS servers
  --clear-ipv6-address        Remove static IPv6 address
  --clear-ipv6-gateway        Remove IPv6 gateway
  --clear-ipv6-dns            Remove all IPv6 DNS servers
  --clear-ssid                Remove SSID binding
  --clear-wifi-security       Remove WiFi security/password
  --clear-interface           Remove interface binding
  --clear-metric              Remove route metric (revert to default)
  --clear-autoconnect         Remove autoconnect override

  Note: --ipv4-method auto and --ipv6-method auto automatically clear
  their respective address/gateway/dns fields unless you explicitly
  provide new values for them.

TRY OPTIONS:
  --timeout-seconds N         Seconds to wait for confirmation (default: 60)

ACTIONS:
  --list                      List all connections
  --show NAME                 Show details for a connection
  --rollback NAME             Restore connection from last persistent backup
  --connection-restart NAME   Bring a connection down and back up
  --examples                  Show example commands for common use cases

FLAGS:
  --dry-run                   Show what would be done; make no changes
  --verbose / -v              Detailed debug output for every step
  --help / -h                 This help

NOTE:
  Most operations require root. Run with sudo or as root.

SETUP COMPLETIONS (once):
  source nmcli-try.sh --setup-completions
EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --connection-name)      CONNECTION_NAME="$2";   shift 2 ;;
            --connection-type)      CONNECTION_TYPE="$2";   shift 2 ;;
            --ssid)                 SSID="$2";              shift 2 ;;
            --wifi-password)        WIFI_PASSWORD="$2";     shift 2 ;;
            --wifi-security)        WIFI_SECURITY="$2";     shift 2 ;;
            --ipv4-method)          IPV4_METHOD="$2";       shift 2 ;;
            --ipv4-address)         IPV4_ADDRESS="$2";      shift 2 ;;
            --ipv4-gateway)         IPV4_GATEWAY="$2";      shift 2 ;;
            --ipv4-dns)             IPV4_DNS="$2";          shift 2 ;;
            --ipv6-method)          IPV6_METHOD="$2";       shift 2 ;;
            --ipv6-address)         IPV6_ADDRESS="$2";      shift 2 ;;
            --ipv6-gateway)         IPV6_GATEWAY="$2";      shift 2 ;;
            --ipv6-dns)             IPV6_DNS="$2";          shift 2 ;;
            --interface)            INTERFACE="$2";         shift 2 ;;
            --autoconnect)          AUTOCONNECT="$2";       shift 2 ;;
            --metric)               METRIC="$2";            shift 2 ;;
            --vlan-id)              VLAN_ID="$2";           shift 2 ;;
            --vlan-parent)          VLAN_PARENT="$2";       shift 2 ;;
            # Clear flags
            --clear-ipv4-address)   CLEAR_IPV4_ADDRESS=1;   shift   ;;
            --clear-ipv4-gateway)   CLEAR_IPV4_GATEWAY=1;   shift   ;;
            --clear-ipv4-dns)       CLEAR_IPV4_DNS=1;       shift   ;;
            --clear-ipv6-address)   CLEAR_IPV6_ADDRESS=1;   shift   ;;
            --clear-ipv6-gateway)   CLEAR_IPV6_GATEWAY=1;   shift   ;;
            --clear-ipv6-dns)       CLEAR_IPV6_DNS=1;       shift   ;;
            --clear-ssid)           CLEAR_SSID=1;           shift   ;;
            --clear-wifi-security)  CLEAR_WIFI_SECURITY=1;  shift   ;;
            --clear-interface)      CLEAR_INTERFACE=1;      shift   ;;
            --clear-metric)         CLEAR_METRIC=1;         shift   ;;
            --clear-autoconnect)    CLEAR_AUTOCONNECT=1;    shift   ;;
            # Actions / flags
            --timeout-seconds)         TIMEOUT="$2";           shift 2 ;;
            --rollback)                ROLLBACK_TARGET="$2";   shift 2 ;;
            --show)                    SHOW_TARGET="$2";       shift 2 ;;
            --connection-restart)      RESTART_TARGET="$2";    shift 2 ;;
            --list)                    LIST_MODE=1;            shift   ;;
            --dry-run)              DRY_RUN=1;              shift   ;;
            --verbose|-v)           VERBOSE=1;              shift   ;;
            --examples)             show_examples; exit 0 ;;
            --help|-h)              usage; exit 0 ;;
            *) err "Unknown argument: $1  (use --help for usage)" ;;
        esac
    done
}

# =============================================================================
# VALIDATION
# =============================================================================

validate() {
    trace "validate: start"
    [[ $LIST_MODE -eq 1 || -n "$SHOW_TARGET" || -n "$ROLLBACK_TARGET" || -n "$RESTART_TARGET" ]] && return

    [[ -n "$CONNECTION_NAME" ]] || err "--connection-name is required."
    verbose "Validating arguments for connection: '$CONNECTION_NAME'"

    [[ "$TIMEOUT" =~ ^[0-9]+$ && $TIMEOUT -ge 1 ]] \
        || err "--timeout-seconds must be a positive integer (got: '${TIMEOUT}')."
    trace "validate: timeout=${TIMEOUT}s OK"

    # Conflict: --clear-* and set value for same property
    [[ $CLEAR_IPV4_ADDRESS -eq 1 && -n "$IPV4_ADDRESS" ]] \
        && err "Cannot use --clear-ipv4-address and --ipv4-address together."
    [[ $CLEAR_IPV4_GATEWAY -eq 1 && -n "$IPV4_GATEWAY" ]] \
        && err "Cannot use --clear-ipv4-gateway and --ipv4-gateway together."
    [[ $CLEAR_IPV4_DNS -eq 1 && -n "$IPV4_DNS" ]] \
        && err "Cannot use --clear-ipv4-dns and --ipv4-dns together."
    [[ $CLEAR_IPV6_ADDRESS -eq 1 && -n "$IPV6_ADDRESS" ]] \
        && err "Cannot use --clear-ipv6-address and --ipv6-address together."
    [[ $CLEAR_IPV6_GATEWAY -eq 1 && -n "$IPV6_GATEWAY" ]] \
        && err "Cannot use --clear-ipv6-gateway and --ipv6-gateway together."
    [[ $CLEAR_IPV6_DNS -eq 1 && -n "$IPV6_DNS" ]] \
        && err "Cannot use --clear-ipv6-dns and --ipv6-dns together."
    [[ $CLEAR_SSID -eq 1 && -n "$SSID" ]] \
        && err "Cannot use --clear-ssid and --ssid together."
    [[ $CLEAR_WIFI_SECURITY -eq 1 && -n "$WIFI_SECURITY" ]] \
        && err "Cannot use --clear-wifi-security and --wifi-security together."
    [[ $CLEAR_INTERFACE -eq 1 && -n "$INTERFACE" ]] \
        && err "Cannot use --clear-interface and --interface together."
    [[ $CLEAR_METRIC -eq 1 && -n "$METRIC" ]] \
        && err "Cannot use --clear-metric and --metric together."
    [[ $CLEAR_AUTOCONNECT -eq 1 && -n "$AUTOCONNECT" ]] \
        && err "Cannot use --clear-autoconnect and --autoconnect together."

    if [[ -n "$CONNECTION_TYPE" ]]; then
        local valid_types="wifi ethernet vpn bridge bond vlan dummy"
        [[ " $valid_types " == *" $CONNECTION_TYPE "* ]] \
            || err "Invalid --connection-type '$CONNECTION_TYPE'. Valid: $valid_types"
        trace "validate: connection-type=$CONNECTION_TYPE OK"
    fi

    if [[ -n "$SSID" || -n "$WIFI_PASSWORD" || -n "$WIFI_SECURITY" ]]; then
        if [[ -n "$CONNECTION_TYPE" && "$CONNECTION_TYPE" != "wifi" ]]; then
            err "--ssid/--wifi-password/--wifi-security require --connection-type wifi."
        fi
    fi

    if [[ -n "$WIFI_SECURITY" ]]; then
        local valid_sec="wpa-psk wpa-eap none"
        [[ " $valid_sec " == *" $WIFI_SECURITY "* ]] \
            || err "Invalid --wifi-security '$WIFI_SECURITY'. Valid: $valid_sec"
        [[ "$WIFI_SECURITY" == "wpa-psk" && -z "$WIFI_PASSWORD" ]] \
            && err "--wifi-security wpa-psk requires --wifi-password."
        trace "validate: wifi-security=$WIFI_SECURITY OK"
    fi

    if [[ -n "$WIFI_PASSWORD" && -z "$WIFI_SECURITY" ]]; then
        WIFI_SECURITY="wpa-psk"
        verbose "Inferred --wifi-security wpa-psk from --wifi-password."
    fi

    if [[ -n "$IPV4_METHOD" ]]; then
        local valid_v4="auto manual disabled link-local"
        [[ " $valid_v4 " == *" $IPV4_METHOD "* ]] \
            || err "Invalid --ipv4-method '$IPV4_METHOD'. Valid: $valid_v4"
        trace "validate: ipv4-method=$IPV4_METHOD OK"
    fi

    if [[ -n "$IPV4_ADDRESS" ]]; then
        [[ -z "$IPV4_METHOD" || "$IPV4_METHOD" == "manual" ]] \
            || err "--ipv4-address conflicts with --ipv4-method '$IPV4_METHOD' (must be manual)."
        local IFS=','; read -ra addr4_list <<< "$IPV4_ADDRESS"
        for addr in "${addr4_list[@]}"; do
            addr="${addr// /}"
            is_valid_cidr "$addr" \
                || err "--ipv4-address '$addr' is not valid CIDR (e.g. 192.168.1.10/24)."
        done
        IPV4_METHOD="manual"
        trace "validate: ipv4-address=$IPV4_ADDRESS OK, method set to manual"
    fi

    if [[ "$IPV4_METHOD" == "disabled" ]]; then
        [[ -z "$IPV4_ADDRESS$IPV4_GATEWAY$IPV4_DNS" ]] \
            || err "Cannot set IPv4 address/gateway/dns with --ipv4-method disabled."
    fi

    if [[ -n "$IPV4_GATEWAY" ]]; then
        is_valid_ip "$IPV4_GATEWAY" \
            || err "--ipv4-gateway '$IPV4_GATEWAY' is not a valid IP."
        trace "validate: ipv4-gateway=$IPV4_GATEWAY OK"
        if [[ -n "$IPV4_ADDRESS" ]]; then
            local _first4="${IPV4_ADDRESS%%,*}"
            local prefix="${_first4#*/}"
            if [[ $prefix -ge 8 && $prefix -le 30 ]]; then
                local cut=$(( 4 - (32 - prefix + 7) / 8 ))
                local a; a=$(echo "${_first4%/*}" | cut -d. -f1-$cut)
                local g; g=$(echo "$IPV4_GATEWAY"      | cut -d. -f1-$cut)
                [[ "$a" == "$g" ]] \
                    || warn "--ipv4-gateway $IPV4_GATEWAY may not be in subnet $IPV4_ADDRESS"
            fi
        fi
    fi

    if [[ -n "$IPV4_DNS" ]]; then
        local IFS=','; read -ra dns_list <<< "$IPV4_DNS"
        for dns in "${dns_list[@]}"; do
            dns="${dns// /}"
            is_valid_ip "$dns" || err "--ipv4-dns entry '$dns' is not a valid IP."
        done
        trace "validate: ipv4-dns OK"
    fi

    if [[ -n "$IPV6_METHOD" ]]; then
        local valid_v6="auto manual disabled ignore link-local"
        [[ " $valid_v6 " == *" $IPV6_METHOD "* ]] \
            || err "Invalid --ipv6-method '$IPV6_METHOD'. Valid: $valid_v6"
        trace "validate: ipv6-method=$IPV6_METHOD OK"
    fi

    if [[ -n "$IPV6_ADDRESS" ]]; then
        [[ -z "$IPV6_METHOD" || "$IPV6_METHOD" == "manual" ]] \
            || err "--ipv6-address conflicts with --ipv6-method '$IPV6_METHOD' (must be manual)."
        local IFS=','; read -ra addr6_list <<< "$IPV6_ADDRESS"
        for addr in "${addr6_list[@]}"; do
            addr="${addr// /}"
            is_valid_cidr "$addr" \
                || err "--ipv6-address '$addr' is not a valid IPv6 CIDR."
        done
        IPV6_METHOD="manual"
        trace "validate: ipv6-address=$IPV6_ADDRESS OK"
    fi

    if [[ "$IPV6_METHOD" == "disabled" || "$IPV6_METHOD" == "ignore" ]]; then
        [[ -z "$IPV6_ADDRESS$IPV6_GATEWAY$IPV6_DNS" ]] \
            || err "Cannot set IPv6 address/gateway/dns with --ipv6-method $IPV6_METHOD."
    fi

    if [[ -n "$IPV6_DNS" ]]; then
        local IFS=','; read -ra dns_list <<< "$IPV6_DNS"
        for dns in "${dns_list[@]}"; do
            dns="${dns// /}"
            is_valid_ip "$dns" || err "--ipv6-dns entry '$dns' is not a valid IP."
        done
        trace "validate: ipv6-dns OK"
    fi

    if [[ -n "$AUTOCONNECT" ]]; then
        [[ "$AUTOCONNECT" == "yes" || "$AUTOCONNECT" == "no" ]] \
            || err "--autoconnect must be 'yes' or 'no'."
        trace "validate: autoconnect=$AUTOCONNECT OK"
    fi

    [[ -z "$METRIC" || "$METRIC" =~ ^[0-9]+$ ]] \
        || err "--metric must be a non-negative integer."

    if [[ -n "$VLAN_ID" ]]; then
        [[ -z "$CONNECTION_TYPE" || "$CONNECTION_TYPE" == "vlan" ]] \
            || err "--vlan-id is only valid with --connection-type vlan."
        [[ "$VLAN_ID" =~ ^[0-9]+$ && $VLAN_ID -le 4094 ]] \
            || err "--vlan-id must be 0–4094."
        [[ -n "$VLAN_PARENT" ]] || err "--vlan-id requires --vlan-parent."
        trace "validate: vlan-id=$VLAN_ID vlan-parent=$VLAN_PARENT OK"
    fi
    [[ -z "$VLAN_PARENT" || -n "$VLAN_ID" ]] \
        || err "--vlan-parent requires --vlan-id."

    if [[ -n "$INTERFACE" ]]; then
        if is_valid_interface "$INTERFACE"; then
            trace "validate: interface=$INTERFACE OK"
        else
            warn "Interface '$INTERFACE' not found on this system. Proceeding anyway."
        fi
    fi

    # Ensure at least one change or clear was requested
    local has_changes=0
    for v in CONNECTION_TYPE SSID WIFI_PASSWORD WIFI_SECURITY \
              IPV4_METHOD IPV4_ADDRESS IPV4_GATEWAY IPV4_DNS \
              IPV6_METHOD IPV6_ADDRESS IPV6_GATEWAY IPV6_DNS \
              INTERFACE AUTOCONNECT METRIC VLAN_ID VLAN_PARENT; do
        if [[ -n "${!v}" ]]; then
            trace "validate: change detected — $v='${!v}'"
            has_changes=1; break
        fi
    done
    for v in CLEAR_IPV4_ADDRESS CLEAR_IPV4_GATEWAY CLEAR_IPV4_DNS \
              CLEAR_IPV6_ADDRESS CLEAR_IPV6_GATEWAY CLEAR_IPV6_DNS \
              CLEAR_SSID CLEAR_WIFI_SECURITY CLEAR_INTERFACE \
              CLEAR_METRIC CLEAR_AUTOCONNECT; do
        if [[ "${!v}" -eq 1 ]]; then
            trace "validate: clear detected — $v"
            has_changes=1; break
        fi
    done
    [[ $has_changes -eq 1 ]] \
        || err "No changes specified. Provide at least one option to modify or --clear-* to remove."

    verbose "Validation passed."
}

# =============================================================================
# BUILD & APPLY NMCLI COMMAND
# =============================================================================

# Emit a field into the arg array, either clearing it or setting it.
# Usage: emit_field _out "nmcli.field" "$VALUE" "$CLEAR_FLAG" "label"
emit_field() {
    local -n __arr=$1
    local field="$2"
    local value="$3"
    local clear_flag="$4"
    local label="${5:-$field}"

    if [[ "$clear_flag" -eq 1 ]]; then
        __arr+=("$field" "")
        trace "  + $label='' (cleared)"
    elif [[ -n "$value" ]]; then
        __arr+=("$field" "$value")
        trace "  + $label=$value"
    fi
}

build_nmcli_args() {
    local name="$CONNECTION_NAME"
    local -n _out=$1

    local exists=0
    connection_exists "$name" && exists=1 || true
    trace "build_nmcli_args: exists=$exists"

    if [[ $exists -eq 1 ]]; then
        verbose "Connection '$name' exists — building modify command."
        _out=("con" "modify" "$name")
        [[ -n "$CONNECTION_TYPE" ]] && { _out+=("connection.type" "$CONNECTION_TYPE"); trace "  + connection.type=$CONNECTION_TYPE"; }
    else
        local type="${CONNECTION_TYPE:-ethernet}"
        verbose "Connection '$name' not found — building add command (type=$type)."
        _out=("con" "add" "type" "$type" "con-name" "$name")
        [[ -n "$VLAN_ID" ]] && { _out+=("id" "$VLAN_ID" "dev" "$VLAN_PARENT"); trace "  + vlan id=$VLAN_ID dev=$VLAN_PARENT"; }
    fi

    # Interface
    emit_field _out "connection.interface-name" "$INTERFACE"    "$CLEAR_INTERFACE"    "interface"

    # WiFi SSID
    emit_field _out "802-11-wireless.ssid"       "$SSID"        "$CLEAR_SSID"         "ssid"

    # For new connections, ifname is set differently
    if [[ $exists -eq 0 && -n "$INTERFACE" ]]; then
        # Already added above via emit_field — but for 'add' we use ifname not
        # connection.interface-name, so fix it up
        _out[-2]="ifname"
    fi

    # WiFi security
    if [[ $CLEAR_WIFI_SECURITY -eq 1 ]]; then
        _out+=("wifi-sec.key-mgmt" "" "wifi-sec.psk" "")
        trace "  + wifi-sec.key-mgmt='' wifi-sec.psk='' (cleared)"
    elif [[ -n "$WIFI_SECURITY" && "$WIFI_SECURITY" != "none" ]]; then
        _out+=("wifi-sec.key-mgmt" "$WIFI_SECURITY")
        trace "  + wifi-sec.key-mgmt=$WIFI_SECURITY"
        [[ -n "$WIFI_PASSWORD" ]] && { _out+=("wifi-sec.psk" "$WIFI_PASSWORD"); trace "  + wifi-sec.psk=<hidden>"; }
    elif [[ "$WIFI_SECURITY" == "none" ]]; then
        _out+=("wifi-sec.key-mgmt" "" "wifi-sec.psk" "")
        trace "  + wifi-sec.key-mgmt='' wifi-sec.psk='' (open network)"
    fi

    # IPv4 method — auto/link-local automatically clears address/gateway/dns
    # unless the user explicitly provided or cleared them
    if [[ -n "$IPV4_METHOD" ]]; then
        _out+=("ipv4.method" "$IPV4_METHOD")
        trace "  + ipv4.method=$IPV4_METHOD"
        if [[ "$IPV4_METHOD" == "auto" || "$IPV4_METHOD" == "link-local" ]]; then
            [[ -z "$IPV4_ADDRESS" && $CLEAR_IPV4_ADDRESS -eq 0 ]] && { CLEAR_IPV4_ADDRESS=1; verbose "Auto-clearing ipv4.addresses (method=$IPV4_METHOD)"; }
            [[ -z "$IPV4_GATEWAY" && $CLEAR_IPV4_GATEWAY -eq 0 ]] && { CLEAR_IPV4_GATEWAY=1; verbose "Auto-clearing ipv4.gateway (method=$IPV4_METHOD)"; }
            [[ -z "$IPV4_DNS"     && $CLEAR_IPV4_DNS     -eq 0 ]] && { CLEAR_IPV4_DNS=1;     verbose "Auto-clearing ipv4.dns (method=$IPV4_METHOD)"; }
        fi
        if [[ "$IPV4_METHOD" == "disabled" ]]; then
            [[ -z "$IPV4_ADDRESS" && $CLEAR_IPV4_ADDRESS -eq 0 ]] && { CLEAR_IPV4_ADDRESS=1; verbose "Auto-clearing ipv4.addresses (method=disabled)"; }
            [[ -z "$IPV4_GATEWAY" && $CLEAR_IPV4_GATEWAY -eq 0 ]] && { CLEAR_IPV4_GATEWAY=1; verbose "Auto-clearing ipv4.gateway (method=disabled)"; }
            [[ -z "$IPV4_DNS"     && $CLEAR_IPV4_DNS     -eq 0 ]] && { CLEAR_IPV4_DNS=1;     verbose "Auto-clearing ipv4.dns (method=disabled)"; }
        fi
    fi

    emit_field _out "ipv4.addresses" "${IPV4_ADDRESS//,/ }"   "$CLEAR_IPV4_ADDRESS" "ipv4.addresses"
    emit_field _out "ipv4.gateway"   "$IPV4_GATEWAY"          "$CLEAR_IPV4_GATEWAY" "ipv4.gateway"
    emit_field _out "ipv4.dns"       "${IPV4_DNS//,/ }"       "$CLEAR_IPV4_DNS"     "ipv4.dns"

    # IPv6 method — auto/ignore clears address/gateway/dns
    if [[ -n "$IPV6_METHOD" ]]; then
        _out+=("ipv6.method" "$IPV6_METHOD")
        trace "  + ipv6.method=$IPV6_METHOD"
        if [[ "$IPV6_METHOD" == "auto" || "$IPV6_METHOD" == "link-local" || "$IPV6_METHOD" == "ignore" ]]; then
            [[ -z "$IPV6_ADDRESS" && $CLEAR_IPV6_ADDRESS -eq 0 ]] && { CLEAR_IPV6_ADDRESS=1; verbose "Auto-clearing ipv6.addresses (method=$IPV6_METHOD)"; }
            [[ -z "$IPV6_GATEWAY" && $CLEAR_IPV6_GATEWAY -eq 0 ]] && { CLEAR_IPV6_GATEWAY=1; verbose "Auto-clearing ipv6.gateway (method=$IPV6_METHOD)"; }
            [[ -z "$IPV6_DNS"     && $CLEAR_IPV6_DNS     -eq 0 ]] && { CLEAR_IPV6_DNS=1;     verbose "Auto-clearing ipv6.dns (method=$IPV6_METHOD)"; }
        fi
        if [[ "$IPV6_METHOD" == "disabled" ]]; then
            [[ -z "$IPV6_ADDRESS" && $CLEAR_IPV6_ADDRESS -eq 0 ]] && { CLEAR_IPV6_ADDRESS=1; verbose "Auto-clearing ipv6.addresses (method=disabled)"; }
            [[ -z "$IPV6_GATEWAY" && $CLEAR_IPV6_GATEWAY -eq 0 ]] && { CLEAR_IPV6_GATEWAY=1; verbose "Auto-clearing ipv6.gateway (method=disabled)"; }
            [[ -z "$IPV6_DNS"     && $CLEAR_IPV6_DNS     -eq 0 ]] && { CLEAR_IPV6_DNS=1;     verbose "Auto-clearing ipv6.dns (method=disabled)"; }
        fi
    fi

    emit_field _out "ipv6.addresses" "${IPV6_ADDRESS//,/ }"   "$CLEAR_IPV6_ADDRESS" "ipv6.addresses"
    emit_field _out "ipv6.gateway"   "$IPV6_GATEWAY"          "$CLEAR_IPV6_GATEWAY" "ipv6.gateway"
    emit_field _out "ipv6.dns"       "${IPV6_DNS//,/ }"       "$CLEAR_IPV6_DNS"     "ipv6.dns"

    # Autoconnect
    emit_field _out "connection.autoconnect" "$AUTOCONNECT"   "$CLEAR_AUTOCONNECT"  "autoconnect"

    # Metric
    emit_field _out "ipv4.route-metric"      "$METRIC"        "$CLEAR_METRIC"       "metric"

    verbose "Final nmcli command: nmcli ${_out[*]}"
}

# =============================================================================
# APPLY
# =============================================================================

apply_and_try() {
    local name="$CONNECTION_NAME"
    trace "apply_and_try: start for '$name'"

    save_persistent_backup "$name"

    log "Creating session backup..."
    mkdir -p "$BACKUP_DIR"
    local conn_files=(/etc/NetworkManager/system-connections/*)
    if [[ -e "${conn_files[0]}" ]]; then
        if cp -r /etc/NetworkManager/system-connections/. "$BACKUP_DIR/"; then
            log "Session backup: $BACKUP_DIR ($(ls "$BACKUP_DIR" | wc -l) files)"
        else
            err "Failed to create session backup — cannot read connection files. Are you running as root?"
        fi
    else
        log "No existing connections to back up."
    fi

    local nmcli_args=()
    build_nmcli_args nmcli_args

    log "Running: nmcli ${nmcli_args[*]}"

    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY-RUN] No changes made."
        trap - EXIT SIGINT SIGTERM SIGHUP
        rm -rf "$BACKUP_DIR"
        exit 0
    fi

    trace "apply_and_try: calling nmcli"
    if nmcli "${nmcli_args[@]}"; then
        verbose "nmcli apply succeeded."
    else
        local rc=$?
        err "nmcli failed with exit code $rc. No changes were committed. Nothing to roll back."
    fi
    CONNECTION_APPLIED=true
    trace "apply_and_try: CONNECTION_APPLIED=true"

    log "Activating '$name'..."
    if nmcli connection up "$name"; then
        verbose "Connection '$name' activated successfully."
    else
        warn "Failed to activate connection '$name'."
        warn "Common causes: wrong interface name, adapter unavailable, bad SSID/password."
        warn "Check interfaces with: nmcli device status"
        exit 1
    fi

    echo ""
    echo "=========================================="
    echo " Configuration applied: $name"
    echo "=========================================="
    nmcli connection show "$name" \
        | grep -E "^(IP4\.|IP6\.|GENERAL\.DEVICES|connection\.interface-name)" || true
    echo ""

    trace "apply_and_try: checking connectivity"
    if ping -c1 -W3 8.8.8.8 &>/dev/null; then
        verbose "Connectivity check passed (ping 8.8.8.8 OK)."
    else
        warn "No internet connectivity detected (ping 8.8.8.8 failed)."
    fi

    echo "------------------------------------------"
    echo "Type 'yes' within $TIMEOUT seconds to keep this configuration."
    echo "Press Ctrl+C or wait to roll back automatically."
    echo "------------------------------------------"
    echo ""

    local response=""
    if read -r -t "$TIMEOUT" -p "Accept new configuration? [y/yes]: " response; then
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                log "Configuration accepted."
                trap - EXIT SIGINT SIGTERM SIGHUP
                rm -rf "$BACKUP_DIR"
                echo ""
                log "Done! '$name' is now active."
                log "View:   nmcli connection show '$name'"
                log "Modify: nmcli-try.sh --connection-name '$name' [options]"
                log "Undo:   nmcli-try.sh --rollback '$name'"
                exit 0
                ;;
            *)
                warn "Input '$response' not recognised. Expected 'y' or 'yes'. Rolling back..."
                exit 1
                ;;
        esac
    else
        warn "Timeout after ${TIMEOUT}s. Rolling back..."
        exit 1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

preflight

parse_args "$@"

verbose "Arguments parsed."
verbose "  CONNECTION_NAME='$CONNECTION_NAME'"
verbose "  CONNECTION_TYPE='$CONNECTION_TYPE'"
verbose "  IPV4_METHOD='$IPV4_METHOD'"
verbose "  IPV4_ADDRESS='$IPV4_ADDRESS'"
verbose "  IPV4_GATEWAY='$IPV4_GATEWAY'"
verbose "  IPV4_DNS='$IPV4_DNS'"
verbose "  IPV6_METHOD='$IPV6_METHOD'"
verbose "  IPV6_ADDRESS='$IPV6_ADDRESS'"
verbose "  IPV6_GATEWAY='$IPV6_GATEWAY'"
verbose "  IPV6_DNS='$IPV6_DNS'"
verbose "  INTERFACE='$INTERFACE'"
verbose "  TIMEOUT=${TIMEOUT}s"
verbose "  DRY_RUN=$DRY_RUN"
verbose "  EUID=$EUID"
verbose "  CLEAR_IPV4_ADDRESS=$CLEAR_IPV4_ADDRESS  CLEAR_IPV4_GATEWAY=$CLEAR_IPV4_GATEWAY  CLEAR_IPV4_DNS=$CLEAR_IPV4_DNS"
verbose "  CLEAR_IPV6_ADDRESS=$CLEAR_IPV6_ADDRESS  CLEAR_IPV6_GATEWAY=$CLEAR_IPV6_GATEWAY  CLEAR_IPV6_DNS=$CLEAR_IPV6_DNS"
verbose "  CLEAR_SSID=$CLEAR_SSID  CLEAR_WIFI_SECURITY=$CLEAR_WIFI_SECURITY"
verbose "  CLEAR_INTERFACE=$CLEAR_INTERFACE  CLEAR_METRIC=$CLEAR_METRIC  CLEAR_AUTOCONNECT=$CLEAR_AUTOCONNECT"

# Read-only actions — no root or trap needed
if [[ $LIST_MODE -eq 1 ]]; then
    nmcli connection show
    exit 0
fi

if [[ -n "$SHOW_TARGET" ]]; then
    show_exists=0
    connection_exists "$SHOW_TARGET" && show_exists=1 || true
    [[ $show_exists -eq 1 ]] || err "Connection '$SHOW_TARGET' not found."
    nmcli connection show "$SHOW_TARGET"
    exit 0
fi

# Everything beyond here requires root
require_root
verbose "Root check passed (EUID=$EUID)."

if [[ -n "$ROLLBACK_TARGET" ]]; then
    do_named_rollback "$ROLLBACK_TARGET"
    exit 0
fi

if [[ -n "$RESTART_TARGET" ]]; then
    do_connection_restart "$RESTART_TARGET"
    exit 0
fi

validate

trap do_rollback_on_exit EXIT SIGINT SIGTERM SIGHUP
trace "main: trap armed"

apply_and_try
