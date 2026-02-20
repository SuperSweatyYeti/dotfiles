#!/usr/bin/env zsh
#!/bin/zsh
# Replicates "netplan try" functionality with NetworkManager
# Usage: ./nm-try.zsh [--timeout-seconds SECONDS]
#
# To enable zsh completion, add this to your ~/.zshrc:
#   source /path/to/nm-try.zsh

# =============================================================================
# ZSH COMPLETION
# =============================================================================
# If being sourced, only set up completion and return
if [[ "${ZSH_EVAL_CONTEXT}" == *:file ]]; then
    # Enable completion system
    autoload -Uz compinit
    compinit 2>/dev/null
    
    _nm_try_completion_zsh() {
        local -a opts timeout_values
        opts=(
            '--timeout-seconds:timeout in seconds before auto-rollback'
            '--help:show help message'
            '-h:show help message'
        )
        
        timeout_values=(30 60 90 120 180 300)
        
        # Check if we're completing after --timeout-seconds
        if [[ ${words[CURRENT-1]} == "--timeout-seconds" ]]; then
            _describe 'timeout values' timeout_values
            return 0
        fi
        
        _describe 'options' opts
    }
    
    # Register completion for various ways the script might be called
    compdef _nm_try_completion_zsh nm-try.zsh
    compdef _nm_try_completion_zsh nm-try
    compdef _nm_try_completion_zsh ./nm-try.zsh
    
    # Also register for the full path if it's in a standard location
    if [[ -f /usr/local/bin/nm-try ]]; then
        compdef _nm_try_completion_zsh /usr/local/bin/nm-try
    fi
    
    return 0
fi

# =============================================================================
# MAIN SCRIPT
# =============================================================================

# Default values
TIMEOUT=60
CONNECTION_NAME=""
BACKUP_DIR="/tmp/nm-backup-$(date +%s)"

# Cleanup function for trap
cleanup_and_rollback() {
    echo ""
    echo ""
    echo "⚠ Interrupted! Rolling back changes..."
    
    # Delete new connection if it was created
    if [[ -n "$CONNECTION_NAME" ]]; then
        nmcli connection delete "$CONNECTION_NAME" 2>/dev/null
    fi
    
    # Restore backup if it exists
    if [[ -d "$BACKUP_DIR" ]]; then
        rm -rf /etc/NetworkManager/system-connections/*
        cp -r "$BACKUP_DIR"/* /etc/NetworkManager/system-connections/ 2>/dev/null
        chmod 600 /etc/NetworkManager/system-connections/* 2>/dev/null
        
        # Reload NetworkManager
        nmcli connection reload
        
        # Try to bring up previous default connection
        OLD_CONNECTION=$(ls -t "$BACKUP_DIR" | head -1 | sed 's/.nmconnection$//')
        if [[ -n "$OLD_CONNECTION" ]]; then
            echo "Attempting to restore: $OLD_CONNECTION"
            nmcli connection up "$OLD_CONNECTION" 2>/dev/null || true
        fi
        
        echo "✓ Rolled back to previous configuration!"
        
        # Clean up backup directory
        rm -rf "$BACKUP_DIR"
    fi
    
    exit 1
}

# Set up trap for cleanup on exit signals
trap cleanup_and_rollback SIGINT SIGTERM SIGHUP EXIT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout-seconds)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            # Disable trap for normal help exit
            trap - EXIT
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --timeout-seconds SECONDS    Timeout in seconds before auto-rollback (default: 60)"
            echo "  -h, --help                   Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Use default 60 second timeout"
            echo "  $0 --timeout-seconds 120     # Use 120 second timeout"
            echo ""
            echo "Zsh Completion:"
            echo "  Add to ~/.zshrc:  source $0"
            exit 0
            ;;
        *)
            trap - EXIT
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate timeout
if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT" -lt 1 ]]; then
    trap - EXIT
    echo "Error: --timeout-seconds must be a positive integer"
    exit 1
fi

echo "Creating backup of current connections..."
mkdir -p "$BACKUP_DIR"
cp -r /etc/NetworkManager/system-connections/* "$BACKUP_DIR/" 2>/dev/null || true

echo "Applying new configuration..."

# =============================================================================
# CONFIGURATION SECTION - Uncomment and modify the section you need
# =============================================================================

# -----------------------------------------------------------------------------
# Example 1: Static WiFi (currently active)
# -----------------------------------------------------------------------------
nmcli connection add \
  type wifi \
  ifname wlan0 \
  con-name "TestStaticWiFi" \
  ssid "CL3DMA" \
  wifi-sec.key-mgmt wpa-psk \
  wifi-sec.psk "YourPassword" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "8.8.8.8 8.8.4.4"

CONNECTION_NAME="TestStaticWiFi"

# -----------------------------------------------------------------------------
# Example 2: DHCP WiFi
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type wifi \
#   ifname wlan0 \
#   con-name "TestDHCPWiFi" \
#   ssid "CL3DMA" \
#   wifi-sec.key-mgmt wpa-psk \
#   wifi-sec.psk "YourPassword" \
#   ipv4.method auto \
#   ipv6.method auto
#
# CONNECTION_NAME="TestDHCPWiFi"

# -----------------------------------------------------------------------------
# Example 3: Static Ethernet
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type ethernet \
#   ifname eth0 \
#   con-name "TestStaticEthernet" \
#   ipv4.method manual \
#   ipv4.addresses 192.168.1.50/24 \
#   ipv4.gateway 192.168.1.1 \
#   ipv4.dns "8.8.8.8 1.1.1.1" \
#   ipv6.method disabled
#
# CONNECTION_NAME="TestStaticEthernet"

# -----------------------------------------------------------------------------
# Example 4: DHCP Ethernet
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type ethernet \
#   ifname eth0 \
#   con-name "TestDHCPEthernet" \
#   ipv4.method auto \
#   ipv6.method auto
#
# CONNECTION_NAME="TestDHCPEthernet"

# -----------------------------------------------------------------------------
# Example 5: Static WiFi with additional options (hidden network, 5GHz, etc.)
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type wifi \
#   ifname wlan0 \
#   con-name "TestAdvancedWiFi" \
#   ssid "HiddenNetwork" \
#   wifi-sec.key-mgmt wpa-psk \
#   wifi-sec.psk "YourPassword" \
#   802-11-wireless.hidden yes \
#   802-11-wireless.band a \
#   ipv4.method manual \
#   ipv4.addresses 10.0.0.100/24 \
#   ipv4.gateway 10.0.0.1 \
#   ipv4.dns "1.1.1.1 1.0.0.1" \
#   ipv4.dns-search "example.local" \
#   ipv6.method disabled
#
# CONNECTION_NAME="TestAdvancedWiFi"

# -----------------------------------------------------------------------------
# Example 6: Static Ethernet with multiple IPs and routes
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type ethernet \
#   ifname eth0 \
#   con-name "TestMultiIPEthernet" \
#   ipv4.method manual \
#   ipv4.addresses "192.168.1.50/24,192.168.1.51/24" \
#   ipv4.gateway 192.168.1.1 \
#   ipv4.dns "8.8.8.8,8.8.4.4" \
#   ipv4.routes "10.0.0.0/8 192.168.1.254" \
#   ipv6.method disabled \
#   connection.autoconnect yes
#
# CONNECTION_NAME="TestMultiIPEthernet"

# -----------------------------------------------------------------------------
# Example 7: WiFi with WPA2 Enterprise (802.1X)
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type wifi \
#   ifname wlan0 \
#   con-name "TestEnterpriseWiFi" \
#   ssid "CorporateNetwork" \
#   wifi-sec.key-mgmt wpa-eap \
#   802-1x.eap peap \
#   802-1x.identity "username" \
#   802-1x.password "password" \
#   802-1x.phase2-auth mschapv2 \
#   ipv4.method auto
#
# CONNECTION_NAME="TestEnterpriseWiFi"

# -----------------------------------------------------------------------------
# Example 8: Open WiFi (no password)
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type wifi \
#   ifname wlan0 \
#   con-name "TestOpenWiFi" \
#   ssid "FreeWiFi" \
#   ipv4.method auto \
#   ipv6.method auto
#
# CONNECTION_NAME="TestOpenWiFi"

# -----------------------------------------------------------------------------
# Example 9: Ethernet with static IPv6
# -----------------------------------------------------------------------------
# nmcli connection add \
#   type ethernet \
#   ifname eth0 \
#   con-name "TestIPv6Ethernet" \
#   ipv4.method auto \
#   ipv6.method manual \
#   ipv6.addresses "2001:db8::100/64" \
#   ipv6.gateway "2001:db8::1" \
#   ipv6.dns "2001:4860:4860::8888"
#
# CONNECTION_NAME="TestIPv6Ethernet"

# -----------------------------------------------------------------------------
# Example 10: Modify existing connection instead of creating new
# -----------------------------------------------------------------------------
# # Modify existing connection
# nmcli connection modify "Wired connection 1" \
#   ipv4.method manual \
#   ipv4.addresses 192.168.1.100/24 \
#   ipv4.gateway 192.168.1.1 \
#   ipv4.dns "8.8.8.8"
#
# CONNECTION_NAME="Wired connection 1"

# =============================================================================
# END CONFIGURATION SECTION
# =============================================================================

# Bring up the connection
echo "Activating connection: $CONNECTION_NAME"
if ! nmcli connection up "$CONNECTION_NAME"; then
    echo "ERROR: Failed to activate connection!"
    # Trap will handle cleanup
    exit 1
fi

echo ""
echo "=========================================="
echo "New configuration applied!"
echo "Connection: $CONNECTION_NAME"
echo "Timeout: $TIMEOUT seconds"
echo "=========================================="
echo ""
echo "Testing network connectivity..."

# Quick connectivity test
if ping -c 2 -W 3 8.8.8.8 &>/dev/null; then
    echo "✓ Internet connectivity confirmed"
else
    echo "⚠ Warning: No internet connectivity detected"
fi

echo ""
echo "Current IP configuration:"
ip addr show | grep -E "inet |inet6 " | grep -v "127.0.0.1" | grep -v "::1"
echo ""

echo "Do you want to keep these settings?"
echo "Press ENTER within $TIMEOUT seconds to keep, or wait to rollback..."
echo "Press Ctrl+C to rollback immediately"
echo ""

# Read with timeout
if read -t "$TIMEOUT" "response?Press ENTER to accept: "; then
    echo ""
    echo "✓ Configuration accepted! Cleaning up backup..."
    
    # Disable trap before successful exit
    trap - EXIT SIGINT SIGTERM SIGHUP
    
    rm -rf "$BACKUP_DIR"
    echo "✓ Done! Connection '$CONNECTION_NAME' is now active."
    echo ""
    echo "To view connection details: nmcli connection show '$CONNECTION_NAME'"
    echo "To modify: nmcli connection modify '$CONNECTION_NAME' [options]"
    echo "To delete: nmcli connection delete '$CONNECTION_NAME'"
    exit 0
else
    echo ""
    echo "⚠ Timeout reached. Rolling back..."
    # Trap will handle the rollback
    exit 1
fi
