#!/usr/bin/env bash

set -euo pipefail

# Script to Detect if we are connected to our HOME lan and prefer locally connected route
# Over the route provided by tailscale

RULE_PREF=5269
TRUSTED_LAN_CURL_QUERY="pfSense-CL3DMA"

cleanup() {
    ip rule del pref "$RULE_PREF" 2>/dev/null || true
}

log() {
    logger -t tailscale-prefer-local-routes "$*"
}

# Tailscale must be running
if [[ "$(tailscale status --json | jq -r '.BackendState')" != "Running" ]]; then
    cleanup
    log "Tailscale stopped; removed local route override."
    exit 0
fi

# No Tailscale routes means nothing to override
if ! ip route show table 52 | grep -q .; then
    cleanup
    log "No Tailscale routes found; removed local route override."
    exit 0
fi

# Look for local connected networks that overlap Tailscale routes
while read -r subnet _ dev _; do

    # Extract an IP from the local interface
    gateway=$(ip route show default dev "$dev" | awk '/default/ {print $3}')

    [[ -z "$gateway" ]] && continue

    # Does Tailscale's table route this gateway?
    if ip route get "$gateway" table 52 >/dev/null 2>&1; then
        continue
    fi

    echo "Verifying trusted gateway via curl..."
    # Verify this is our trusted LAN
    if curl -ks --connect-timeout 2 "https://${gateway}/" |
        grep -q "${TRUSTED_LAN_CURL_QUERY}"; then

        ip rule del pref "$RULE_PREF" 2>/dev/null || true
        ip rule add pref "$RULE_PREF" to "$subnet" lookup main

        log "Preferring local route $subnet via $dev"
        exit 0
    fi

done < <(ip -o -4 route show proto kernel scope link)

cleanup
log "No matching trusted local network found."
