#!/usr/bin/env bash
# Ejecuta Flutter (Windows) contra Azure API Management leyendo frontend/.env.
# Uso desde Git Bash:  bash run-apim.sh   o   ./run-apim.sh
# - No muestra la clave.
# - No usa 'source' ni 'eval': lee únicamente las dos variables esperadas.

set -euo pipefail

# Carpeta donde vive este script (independiente de dónde se invoque).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: no se encontró .env en $SCRIPT_DIR" >&2
  echo "Copia .env.example a .env y completa los valores." >&2
  exit 1
fi

# Lee una variable concreta del .env sin ejecutar su contenido.
# Formato permitido: CLAVE=VALOR o CLAVE = VALOR (espacios opcionales alrededor
# de '='). Tolera CRLF, comentarios con '#', espacios y comillas envolventes.
read_env_var() {
  local key="$1" file="$2" line value re
  value=""
  re="^${key}[[:space:]]*=[[:space:]]*(.*)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"                      # quita CR de finales CRLF
    line="${line#"${line%%[![:space:]]*}"}"   # quita espacios iniciales
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" =~ $re ]]; then
      value="${BASH_REMATCH[1]}"
      while [[ "$value" == *[[:space:]] ]]; do value="${value%?}"; done
      if [[ "$value" == \"*\" && ${#value} -ge 2 ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "$value" == \'*\' && ${#value} -ge 2 ]]; then
        value="${value:1:${#value}-2}"
      fi
      while [[ "$value" == *[[:space:]] ]]; do value="${value%?}"; done
    fi
  done < "$file"
  printf '%s' "$value"
}

APIM_BASE_URL="$(read_env_var APIM_BASE_URL "$ENV_FILE")"
APIM_SUBSCRIPTION_KEY="$(read_env_var APIM_SUBSCRIPTION_KEY "$ENV_FILE")"

if [[ -z "$APIM_BASE_URL" ]]; then
  echo "ERROR: APIM_BASE_URL está vacía o no definida en .env" >&2
  exit 1
fi
if [[ -z "$APIM_SUBSCRIPTION_KEY" ]]; then
  echo "ERROR: APIM_SUBSCRIPTION_KEY está vacía o no definida en .env" >&2
  exit 1
fi

echo "Iniciando Flutter (Windows) contra Azure API Management..."
echo "APIM_BASE_URL = $APIM_BASE_URL"
echo "(la clave no se muestra por seguridad)"

exec flutter run -d windows \
  --dart-define=APIM_BASE_URL="$APIM_BASE_URL" \
  --dart-define=APIM_SUBSCRIPTION_KEY="$APIM_SUBSCRIPTION_KEY"
