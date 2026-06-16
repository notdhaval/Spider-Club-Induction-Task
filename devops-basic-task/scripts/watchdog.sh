#!/bin/bash

# grab current path dynamically so it never breaks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_DIR="$BASE_DIR/test_dir"
MAIN_SCRIPT="$SCRIPT_DIR/vault_sweep.sh"
TEMP_LOG="/tmp/watchdog_scan.tmp"

chmod +x "$MAIN_SCRIPT"

# --- AUTOMATIC CRON SETUP ---
# check if this watchdog is already inside the crontab
if ! crontab -l 2>/dev/null | grep -q "$BASH_SOURCE"; then
    echo "[INFO] Watchdog not found in crontab. Auto-scheduling now..."
    
    # build the 30-minute cron string using our exact path
    CRON_LINE="*/30 * * * * /bin/bash $SCRIPT_DIR/watchdog.sh"
    
    # export current cron, append new line, and load it back up quietly
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "[INFO] Watchdog successfully scheduled for every 30 minutes."
fi
# -----------------------------

# execute core sweep using background mode flag (-b)
"$MAIN_SCRIPT" -b "$TARGET_DIR" > "$TEMP_LOG" 2>&1

# check if any warnings popped up in the sweep output
if grep -q "\[WARN\]" "$TEMP_LOG"; then
    echo "[ALERT] Watchdog detected compromised configs or files!"
    echo "CRITICAL: Spider DevOps Watchdog found active threats in $TARGET_DIR! Check logs immediately." | wall
else
    echo "[INFO] Watchdog run complete. Directory looks clean."
fi

# cleanup temp output
rm -f "$TEMP_LOG"