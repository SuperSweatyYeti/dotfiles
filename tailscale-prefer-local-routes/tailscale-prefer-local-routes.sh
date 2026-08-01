#!/usr/bin/env bash

set -euo pipefail

# Script to detect if we are connected to our HOME LAN and prefer the locally
# connected route over the route provided by Tailscale.

RULE_PREF=100
TRUSTED_LAN_CURL_QUERY="pfSense-CL3DMA"

log() {
    echo "$*" >&2
    logger -t tailscale-prefer-local-routes "$*"
}

cleanup() {
    if ip rule show pref "$RULE_PREF" | grep -q .; then
        ip rule del pref "$RULE_PREF"
        log "Removed local route override."
    fi
}

case "${1:-reconcile}" in
    reconcile)
        ;;
    cleanup)
        cleanup
        exit 0
        ;;
    *)
        echo "Usage: $0 [reconcile|cleanup]" >&2
        exit 2
        ;;
esac

# Tailscale must be running
if [[ "$(tailscale status --json | jq -r '.BackendState')" != "Running" ]]; then
    cleanup
    log "Tailscale not running."
    exit 0
fi

# No Tailscale routes means nothing to override
if ! ip route show table 52 | grep -q .; then
    cleanup
    log "No Tailscale routes found."
    exit 0
fi

# Get the interface used by the default route
default_dev=$(ip -4 route show default | awk '{print $5; exit}')

while read -r subnet _ dev _; do

    # Only process the default route interface, skip loopback, docker, tailscale, etc.
    [[ "$dev" == "$default_dev" ]] || continue
    [[ "$dev" == tailscale* ]] && continue

    # Extract the default gateway for this interface
    gateway=$(ip route show default dev "$dev" 2>/dev/null | awk '/default/ {print $3; exit}')

    [[ -z "$gateway" ]] && continue

    # Skip if Tailscale's table already routes this gateway (no conflict)
    if ip route get "$gateway" table 52 >/dev/null 2>&1; then
        continue
    fi

    # If rule already exists for this subnet, no need to re-verify
    if ip rule show pref "$RULE_PREF" | grep -q "$subnet"; then
        log "Rule already exists for $subnet, skipping."
        exit 0
    fi

    log "Verifying trusted gateway $gateway via curl..."

    if curl -ks --connect-timeout 2 "https://${gateway}/" |
        grep -q "$TRUSTED_LAN_CURL_QUERY"; then

        ip rule del pref "$RULE_PREF" 2>/dev/null || true
        ip rule add pref "$RULE_PREF" to "$subnet" lookup main

        log "Preferring local route $subnet via $dev (gateway $gateway)"
        exit 0
    fi

done < <(ip -o -4 route show proto kernel scope link)

cleanup
log "No matching trusted local network found."
