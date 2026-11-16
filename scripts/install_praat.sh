#!/usr/bin/env bash
# Praat barren fijado a la release histórica utilizada con esta copia de PAROLE.
set -euo pipefail

PRAAT_VERSION="6.4.60"
PRAAT_BUILD="6460"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEST="${BASEDIR}/env/praat"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "La instalación fijada de Praat barren requiere Linux." >&2
  exit 1
fi
case "$(uname -m)" in
  x86_64) ARCH_SUFFIX="linux-intel64" ;;
  aarch64|arm64) ARCH_SUFFIX="linux-arm64" ;;
  *) echo "Arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
esac

version_matches() {
  local version
  version=$("$1" --version 2>&1) || return 1
  [[ "$version" == "Praat ${PRAAT_VERSION} ("* ]]
}

if [[ -x "$DEST/praat_barren" ]] && version_matches "$DEST/praat_barren"; then
  ln -sfn praat_barren "$DEST/praat"
  echo "Praat barren ${PRAAT_VERSION} ya está instalado en $DEST."
  exit 0
fi

PRAAT_FILE="praat${PRAAT_BUILD}_${ARCH_SUFFIX}-barren.tar.gz"
PRAAT_URL="https://github.com/praat/praat.github.io/releases/download/v${PRAAT_VERSION}/${PRAAT_FILE}"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
echo "Descargando $PRAAT_URL"
curl --fail --location --retry 3 "$PRAAT_URL" -o "$TEMP_DIR/praat.tar.gz"
tar -xzf "$TEMP_DIR/praat.tar.gz" -C "$TEMP_DIR"
chmod +x "$TEMP_DIR/praat_barren"
if ! version_matches "$TEMP_DIR/praat_barren"; then
  echo "El binario descargado no corresponde a Praat ${PRAAT_VERSION}." >&2
  exit 1
fi
mkdir -p "$DEST"
install -m 755 "$TEMP_DIR/praat_barren" "$DEST/praat_barren"
ln -sfn praat_barren "$DEST/praat"
"$DEST/praat" --version
