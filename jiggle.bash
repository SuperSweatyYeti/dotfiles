#!/usr/bin/env bash

if ! systemctl --user is-active --quiet ydotool.service; then
    echo "ydotool.service is not running" >&2
    echo "Make sure ydotool is installed and start with 'systemctl --user start ydotool.service'" >&2
    exit 1
fi

DURATION_SECONDS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --seconds)
            if [[ -z "${2:-}" || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
                echo "Error: --seconds requires a positive integer" >&2
                exit 1
            fi
            DURATION_SECONDS="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--seconds N]" >&2
            exit 1
            ;;
    esac
done

if (( DURATION_SECONDS > 0 )); then
    HOURS=$((DURATION_SECONDS / 3600))
    MINUTES=$(( (DURATION_SECONDS % 3600) / 60 ))
    REMAINING_SECONDS=$((DURATION_SECONDS % 60))
    DURATION="${HOURS}H ${MINUTES}m ${REMAINING_SECONDS}s"
else
    DURATION="indefinitely"
fi

ELAPSED=0
START_TIME=$SECONDS

while true; do
    ydotool mousemove -- 2 0
    sleep 1
    ydotool mousemove -- -2 0
    sleep 1

    ELAPSED=$((SECONDS - START_TIME))

    ELAPSED_HOURS=$((ELAPSED / 3600))
    ELAPSED_MINUTES=$(((ELAPSED % 3600) / 60))
    ELAPSED_SECONDS=$((ELAPSED % 60))

    echo "Jiggling mouse... ${ELAPSED_HOURS}H ${ELAPSED_MINUTES}m ${ELAPSED_SECONDS}s elapsed. Will run for $DURATION"

    if (( DURATION_SECONDS > 0 && ELAPSED >= DURATION_SECONDS )); then
        break
    fi
done

