#!/bin/bash
# Docker Project Zomboid Linux Dedicated Server Mod Update Checker & Auto-Restart Script
# Uses rcon run 'checkModsNeedUpdate', parses latest DebugLog-server.txt
# Restarts server if mods need update.

# Tested and used with renegademaster/zomboid-dedicated-server
# https://github.com/Renegade-Master/zomboid-dedicated-server

# CONFIG - EDIT THESE!
RCON_HOST="YOUR_PZ_SERVER_IP"                            # Localhost for self-hosted
RCON_PORT="27015"                                        # From servertest.ini: RCONPort=
RCON_PASS="RCONPASSWORD"                                 # From servertest.ini: RCONPassword=
RCON_BIN="/usr/bin/rcon"                                 # Path to rcon binary
SERVER_DIR="SERVER_DIR"                                  # e.g., SteamCMD install path
DOCKER_COMPOSE_FILE="${SERVER_DIR}/docker-compose.yaml"  # Docker compose config file
LOG_BASE="${SERVER_DIR}/ZomboidConfig/Logs"              # Change if needed
WARN_TIME=600                                            # Warning time in seconds
SLEEP_AFTER_CHECK=15                                     # Seconds to wait for log write

cd "$SERVER_DIR" || { echo "ERROR: Cannot cd to $SERVER_DIR" >&2; exit 1; }

# Send RCON check command
echo "$(date): Checking mods..."
docker compose -f "${DOCKER_COMPOSE_FILE}" exec zomboid "$RCON_BIN" -a "${RCON_HOST}:${RCON_PORT}" -p "$RCON_PASS" "checkModsNeedUpdate"
sleep "$SLEEP_AFTER_CHECK"

# Find newest DebugLog-server.txt (YYYY-MM-DD dated folders)
NEWEST_LOG=$(find "$LOG_BASE" -type f -name "*_DebugLog-server.txt" -printf '%T@ %p\n' 2>/dev/null | sort -r -n | head -1 | cut -d' ' -f2-)
if [ -n "$NEWEST_LOG" ]; then
    echo "Newest log file: $NEWEST_LOG"
else
    echo "$(date): No DebugLog-server.txt found in $LOG_BASE" >&2
    exit 1
fi

# Get the LAST (newest) CheckModsNeedUpdate line from it
LAST_CHECK=$(tail -n 200 "$NEWEST_LOG" | grep -i "Mods need update" | tail -1)
if [[ -z "$LAST_CHECK" ]]; then
    echo "$(date): No recent checkModsNeedUpdate entry in log"
    exit 0
fi

echo "$(date): Last check: $LAST_CHECK"

# If contains "Mods need update", then needs update
if echo "$LAST_CHECK" | grep -qi "Mods need update"; then
    echo "$(date): *** MODS NEED UPDATE! Initiating restart ***"

    # Warn players
    docker compose -f "${DOCKER_COMPOSE_FILE}" exec zomboid "$RCON_BIN" -a "${RCON_HOST}:${RCON_PORT}" -p "$RCON_PASS" \
                'servermsg "Workshop mods updated! Server restarting in '$(($WARN_TIME / 60))' minutes to sync."'
    sleep "$WARN_TIME"

    # Final warnings
    docker compose -f "${DOCKER_COMPOSE_FILE}" exec zomboid "$RCON_BIN" -a "${RCON_HOST}:${RCON_PORT}" -p "$RCON_PASS" 'servermsg "Restarting in 30 seconds!!!"'
    sleep 30
        # Final warning
        docker compose -f "${DOCKER_COMPOSE_FILE}" exec zomboid "$RCON_BIN" -a "${RCON_HOST}:${RCON_PORT}" -p "$RCON_PASS" 'servermsg "Restarting NOW! ..."'
        sleep 3
        docker compose -f ${DOCKER_COMPOSE_FILE} restart zomboid

    echo "$(date): Server restarted successfully."
else
    echo "$(date): Mods up to date. No action needed."
fi
