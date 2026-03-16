#!/bin/bash
# =============================================================================
# run-sitespeed.sh
# Lanza sitespeed.io para cada URL del fichero urls.txt en todas las
# combinaciones de dispositivo, navegador y conectividad.
#
# Combinaciones: 2 dispositivos x 2 navegadores x 4 conectividades = 16 por URL
#
# En Grafana:
#   - testname      → desktop | mobile
#   - browser       → chrome  | firefox
#   - connectivity  → native | cable | 3gfast | 3g | 2g
#
# Uso:
#   bash run-sitespeed.sh ./urls.txt
#   bash run-sitespeed.sh /ruta/alternativa/urls.txt
#
# Crontab (cada 6 horas):
#   0 */6 * * * /opt/sitespeed/run-sitespeed.sh ./urls.txt >> /var/log/sitespeed.log 2>&1
# =============================================================================

DOCKER_IMAGE="sitespeedio/sitespeed.io:39.4.2"
URLS_FILE="${1:-$(dirname "$0")/urls.txt}"

# Red Docker del compose oficial
# Local (Windows): nombre de carpeta + "_default" → comprueba con: docker network ls
# Producción (OVH/Linux): cambia GRAPHITE_HOST a "graphite"
DOCKER_NETWORK="docker_default"
GRAPHITE_HOST="172.26.0.2"
GRAPHITE_PORT="2003"

# ---------------------------------------------------------------------------

if [[ ! -f "$URLS_FILE" ]]; then
  echo "[ERROR] No se encuentra: $URLS_FILE"
  exit 1
fi

TOTAL=0; OK=0; FAIL=0

# ---------------------------------------------------------------------------
# Función principal
# Argumentos: SLUG  BROWSER  VIEWPORT  MOBILE(true|"")  CONNECTIVITY
# ---------------------------------------------------------------------------
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

    # Ignorar aliases — solo usar la URL (primera columna)
    URL=$(echo "$line" | awk '{print $1}')
    TOTAL=$((TOTAL + 1))

    echo ""
    echo "--- [$TOTAL] $URL"

    # Parámetros opcionales
    MOBILE_PARAM=""
    [[ -n "$MOBILE" ]] && MOBILE_PARAM="--mobile true"

    CONNECTIVITY_PARAM=""
    if [[ "$CONNECTIVITY" != "native" ]]; then
      CONNECTIVITY_PARAM="--connectivity.profile $CONNECTIVITY"
    fi

    if docker run --shm-size=1g --rm \
        --cap-add=NET_ADMIN \
        --network "$DOCKER_NETWORK" \
        "$DOCKER_IMAGE" \
        --graphite.host "$GRAPHITE_HOST" \
        --graphite.port "$GRAPHITE_PORT" \
        --slug "$SLUG" \
        --browser "$BROWSER" \
        --browsertime.viewPort "$VIEWPORT" \
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

# ---------------------------------------------------------------------------
# Combinaciones: dispositivo x navegador x conectividad
# ---------------------------------------------------------------------------
echo "========================================================"
echo " Inicio: $(date '+%Y-%m-%d %H:%M:%S')"
echo " URLs:   $URLS_FILE"
echo "========================================================"

for CONNECTIVITY in native cable 3gfast 3g 2g; do
  for BROWSER in chrome firefox; do
    run_tests "desktop" "$BROWSER" "1920x1080" ""     "$CONNECTIVITY"
    run_tests "mobile"  "$BROWSER" "360x640"   "true" "$CONNECTIVITY"
  done
done

echo ""
echo "========================================================"
echo " Fin: $(date '+%Y-%m-%d %H:%M:%S') — OK: $OK | FAIL: $FAIL | Total: $TOTAL"
echo "========================================================"

[[ $FAIL -gt 0 ]] && exit 1
exit 0