#!/bin/bash
# =============================================================================
# init.sh
# Installs the cron jobs defined in ./cron into the current user's crontab.
# Safe to run multiple times — skips entries that are already present.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_FILE="$SCRIPT_DIR/cron"

if [[ ! -f "$CRON_FILE" ]]; then
  echo "[ERROR] Cron file not found: $CRON_FILE"
  exit 1
fi

# Read existing crontab (suppress error if empty)
EXISTING_CRONTAB=$(crontab -l 2>/dev/null)

ADDED=0

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  if echo "$EXISTING_CRONTAB" | grep -qF "$line"; then
    echo "[SKIP]  Already present: $line"
  else
    EXISTING_CRONTAB="${EXISTING_CRONTAB}"$'\n'"$line"
    echo "[ADD]   $line"
    ADDED=$((ADDED + 1))
  fi
done < "$CRON_FILE"

if [[ $ADDED -gt 0 ]]; then
  echo "$EXISTING_CRONTAB" | crontab -
  echo "[OK] $ADDED cron job(s) installed."
else
  echo "[OK] No changes needed — all cron jobs were already present."
fi
