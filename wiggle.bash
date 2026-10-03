#!/usr/bin/env bash

if ! systemctl --user is-active --quiet ydotool.service; then
    echo "ydotool.service is not running" >&2
    echo "Make sure ydotool is installed and start with 'systemctl --user start ydotool.service'" >&2
    exit 1
fi

SECONDS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --seconds)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --seconds requires a positive integer" >&2
                exit 1
            fi
            SECONDS="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--seconds N]" >&2
            exit 1
            ;;
    esac
done

if (( SECONDS > 0 )); then
    HOURS=$((SECONDS / 3600))
    MINUTES=$(( (SECONDS % 3600) / 60 ))
    REMAINING_SECONDS=$((SECONDS % 60))
    DURATION="$HOURS hours $MINUTES minutes $REMAINING_SECONDS seconds"
else
    DURATION="indefinitely"
fi

COUNT=0
START_TIME=$(date +%s)

while true; do
    ydotool mousemove -- 2 0
    sleep 1
    ((COUNT++))

    ydotool mousemove -- -2 0
    sleep 1
    ((COUNT++))

    ELAPSED_HOURS=$((COUNT / 3600))
    ELAPSED_MINUTES=$(((COUNT % 3600) / 60))
    ELAPSED_SECONDS=$((COUNT % 60))

    echo "$ELAPSED_HOURS hours $ELAPSED_MINUTES minutes $ELAPSED_SECONDS seconds elapsed. Jiggling mouse... Will run for $DURATION"

    if (( SECONDS > 0 && $(date +%s) - START_TIME >= SECONDS )); then
        break
    fi
done

