#!/bin/bash
# =============================================================================
# run-sitespeed.sh
# Lanza sitespeed.io para cada URL de urls.txt en combinaciones de
# dispositivo, navegador y conectividad, enviando métricas a Graphite.
#
# En Grafana:
#   testname     → desktop | mobile
#   browser      → chrome  | firefox
#   connectivity → native | cable | 3gfast | 3g | 2g
#
# Uso:
#   bash run-sitespeed.sh ./urls.txt           # modo full (por defecto)
#   bash run-sitespeed.sh ./urls.txt quick     # solo desktop + chrome + native
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env if present
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

DOCKER_IMAGE="sitespeedio/sitespeed.io:39.4.2"
URLS_FILE="${1:-$SCRIPT_DIR/urls.txt}"
MODE="${2:-full}"

# Fallback defaults (overridden by .env)
DOCKER_NETWORK="${DOCKER_NETWORK:-docker_default}"
GRAPHITE_HOST="${GRAPHITE_HOST:-graphite}"
GRAPHITE_PORT="${GRAPHITE_PORT:-2003}"
ITERATIONS="${ITERATIONS:-3}"

# ---------------------------------------------------------------------------

if [[ ! -f "$URLS_FILE" ]]; then
  echo "[ERROR] No se encuentra: $URLS_FILE"
  exit 1
fi

TOTAL=0; OK=0; FAIL=0

run_tests() {
  local SLUG="$1"
  local BROWSER="$2"
  local VIEWPORT="$3"
  local MOBILE="$4"
  local CONNECTIVITY="$5"

  echo ""
  echo "========================================================"
  echo " slug=$SLUG  browser=$BROWSER  connectivity=$CONNECTIVITY"
  echo "========================================================"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    URL=$(echo "$line" | awk '{print $1}')
    TOTAL=$((TOTAL + 1))

    echo ""
    echo "--- [$TOTAL] $URL"

    MOBILE_PARAM=""
    [[ -n "$MOBILE" ]] && MOBILE_PARAM="--mobile true"

    CONNECTIVITY_PARAM=""
    [[ "$CONNECTIVITY" != "native" ]] && CONNECTIVITY_PARAM="--connectivity.profile $CONNECTIVITY"

    if docker run --shm-size=1g --rm \
        --cap-add=NET_ADMIN \
        --network "$DOCKER_NETWORK" \
        "$DOCKER_IMAGE" \
        --graphite.host "$GRAPHITE_HOST" \
        --graphite.port "$GRAPHITE_PORT" \
        --slug "$SLUG" \
        --browser "$BROWSER" \
        --browsertime.viewPort "$VIEWPORT" \
        -n "$ITERATIONS" \
        $MOBILE_PARAM \
        $CONNECTIVITY_PARAM \
        "$URL"; then
      echo "[OK] $URL"
      OK=$((OK + 1))
    else
      echo "[FAIL] $URL"
      FAIL=$((FAIL + 1))
    fi

  done < "$URLS_FILE"
}

echo "========================================================"
echo " Inicio: $(date '+%Y-%m-%d %H:%M:%S')"
echo " URLs:   $URLS_FILE  |  Modo: $MODE"
echo " Graphite: $GRAPHITE_HOST:$GRAPHITE_PORT  |  Network: $DOCKER_NETWORK"
echo "========================================================"

if [[ "$MODE" == "quick" ]]; then
  run_tests "desktop" "chrome" "1920x1080" "" "native"
else
  for CONNECTIVITY in native cable 3gfast 3g 2g; do
    for BROWSER in chrome firefox; do
      run_tests "desktop" "$BROWSER" "1920x1080" ""     "$CONNECTIVITY"
      run_tests "mobile"  "$BROWSER" "360x640"   "true" "$CONNECTIVITY"
    done
  done
fi

echo ""
echo "========================================================"
echo " Fin: $(date '+%Y-%m-%d %H:%M:%S') — OK: $OK | FAIL: $FAIL | Total: $TOTAL"
echo "========================================================"

[[ $FAIL -gt 0 ]] && exit 1
exit 0