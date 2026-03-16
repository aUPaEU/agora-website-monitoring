#!/bin/bash
# =============================================================================
# init.sh
# 1. Creates .env from .env.example if it doesn't exist
# 2. Installs cron jobs from ./cron
#
# Safe to run multiple times.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
CRON_FILE="$SCRIPT_DIR/cron"

# ---------------------------------------------------------------------------
# 1. Create .env from .env.example if needed
# ---------------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "[INFO] Created .env from .env.example — edit it before running tests."
  else
    echo "[WARN] No .env or .env.example found. Defaults will be used."
  fi
else
  echo "[INFO] .env already exists — skipping creation."
fi

# ---------------------------------------------------------------------------
# 2. Install cron jobs
# ---------------------------------------------------------------------------
if [[ ! -f "$CRON_FILE" ]]; then
  echo "[ERROR] Cron file not found: $CRON_FILE"
  exit 1
fi

EXISTING_CRONTAB=$(crontab -l 2>/dev/null)
ADDED=0

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  line="${line//DEPLOY_PATH/$SCRIPT_DIR}"

  if echo "$EXISTING_CRONTAB" | grep -qF "$line"; then
    echo "[SKIP] Already present: $line"
  else
    EXISTING_CRONTAB="${EXISTING_CRONTAB}"$'\n'"$line"
    echo "[ADD]  $line"
    ADDED=$((ADDED + 1))
  fi
done < "$CRON_FILE"

if [[ $ADDED -gt 0 ]]; then
  echo "$EXISTING_CRONTAB" | crontab -
  echo "[OK] $ADDED cron job(s) installed."
else
  echo "[OK] No changes needed — all cron jobs already present."
fi