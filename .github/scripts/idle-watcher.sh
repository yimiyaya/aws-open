#!/bin/bash

# Default timeout 120s
TIMEOUT=${IDLE_TIMEOUT:-120}

if [ "$TIMEOUT" -le 0 ]; then
    echo "Idle timeout is set to $TIMEOUT. Idle watcher is disabled."
    exit 0
fi

CHECK_INTERVAL=30
IDLE_TIME=0

echo "Starting idle watcher with timeout: ${TIMEOUT}s (Tailscale active status only)"

while true; do
    # Get local info to filter out
    MY_TS_IP=$(tailscale ip -4 || echo "___none___")

    # Check for active Tailscale sessions (excluding local node)
    # We filter out our own IP and Hostname
    SESSION_TS_RAW=$(tailscale status --active | grep -v "$MY_TS_IP" || true)

    if [ -n "$SESSION_TS_RAW" ]; then
        # Active Tailscale sessions found
        if [ $IDLE_TIME -ne 0 ]; then
            echo "$(date): Tailscale activity detected. Resetting idle timer."
        fi
        IDLE_TIME=0
    else
        # No active Tailscale sessions found
        IDLE_TIME=$((IDLE_TIME + CHECK_INTERVAL))
        if [ $((IDLE_TIME % 60)) -eq 0 ] || [ $IDLE_TIME -ge $TIMEOUT ]; then
            echo "$(date): No active Tailscale sessions. Idle for ${IDLE_TIME}s (Timeout: ${TIMEOUT}s)."
        fi

        if [ $IDLE_TIME -ge $TIMEOUT ]; then
            echo "$(date): Idle timeout reached. Triggering shutdown."
            /usr/local/bin/action-shutdown
            break
        fi
    fi
    sleep $CHECK_INTERVAL
done
