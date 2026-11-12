"""Descarga y verifica el dataset publico de Kaggle usado para entrenar el modelo.

El dataset "University Student Mental Health Indicators" esta publicado bajo
licencia CC0 (dominio publico), por lo que puede redistribuirse y versionarse
en el repositorio. La copia versionada en ``ml/data`` es la que usan el
entrenamiento y las pruebas; este script solo sirve para refrescarla.

Uso:
    python download_dataset.py            # verifica la copia local
    python download_dataset.py --refresh  # vuelve a descargarla y valida el hash

Las variables de entorno se leen obligatoriamente del archivo .env (regla de
seguridad del proyecto). No se registran secretos en los logs.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

from dotenv import load_dotenv

RAIZ_ML = Path(__file__).resolve().parent
RUTA_DATASET = RAIZ_ML / "data" / "mental_health_indicators.csv"

# API publica de Kaggle: no requiere credenciales para datasets publicos.
URL_API = (
    "https://www.kaggle.com/api/v1/datasets/download/"
    "yuanchunhong/university-student-mental-health-indicators"
)

SHA256_ESPERADO = "BB27C2A3D0046FA4C615D8C6222F5AC1C441B1F7CB780534CC1B73239968CF38"

# Licencia declarada por el propietario del dataset en Kaggle.
LICENCIA = "CC0-1.0 (CC0: Public Domain)"


def calcular_sha256(ruta: Path) -> str:
    """Devuelve el SHA256 de un archivo leído por bloques."""
    resumen = hashlib.sha256()
    with ruta.open("rb") as archivo:
        for bloque in iter(lambda: archivo.read(65536), b""):
            resumen.update(bloque)
    return resumen.hexdigest().upper()


def verificar(ruta: Path) -> bool:
    """Comprueba que el dataset local exista y conserve el hash esperado."""
    if not ruta.exists():
        print(f"[ERROR] No existe el dataset en {ruta}")
        return False

    hash_actual = calcular_sha256(ruta)
    if hash_actual != SHA256_ESPERADO:
        print("[ERROR] El hash SHA256 del dataset local no coincide.")
        print(f"        esperado: {SHA256_ESPERADO}")
        print(f"        actual:   {hash_actual}")
        return False

    print(f"[OK] Dataset verificado: {ruta.name}")
    print(f"     SHA256: {hash_actual}")
    print(f"     Licencia: {LICENCIA}")
    return True


def descargar(ruta: Path) -> bool:
    """Descarga el dataset desde la API publica de Kaggle y valida el hash."""
    print(f"Descargando dataset desde {URL_API}")
    try:
        with urllib.request.urlopen(URL_API, timeout=120) as respuesta:
            contenido = respuesta.read()
    except OSError as error:
        print(f"[ERROR] No se pudo descargar el dataset: {error}")
        return False

    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_bytes(contenido)
    print(f"Dataset escrito en {ruta} ({len(contenido)} bytes)")

    return verificar(ruta)


def main() -> int:
    """Punto de entrada del script de descarga."""
    load_dotenv(RAIZ_ML.parent / ".env")

    analizador = argparse.ArgumentParser(description=__doc__)
    analizador.add_argument(
        "--refresh",
        action="store_true",
        help="Vuelve a descargar el dataset en lugar de solo verificarlo.",
    )
    argumentos = analizador.parse_args()

    if argumentos.refresh:
        return 0 if descargar(RUTA_DATASET) else 1

    return 0 if verificar(RUTA_DATASET) else 1


if __name__ == "__main__":
    sys.exit(main())
