#!/usr/bin/env bash
#
# Uso:
#   ./scripts/parole_batch.sh data/videos resultados [--parquet]
#
# Este script ejecuta `parole.sh` sobre todos los videos .mp4 en la carpeta especificada,
# y guarda los resultados en subcarpetas dentro del directorio de salida.

# --------------------------------------------------------------------
# --- 0. Validación de argumentos ---
# --------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "Uso: $0 <carpeta_videos> <carpeta_salida> [--parquet]"
  exit 1
fi

VIDEODIR="$1"
OUTDIR="$2"
FORMAT_FLAG=""

if [ "$3" == "--parquet" ]; then
  FORMAT_FLAG="--parquet"
fi

# Crear carpeta de salida si no existe
mkdir -p "$OUTDIR"

# Obtener lista de archivos .mp4
mapfile -t VIDEO_FILES < <(find "$VIDEODIR" -type f -name "*.mp4" | sort)

TOTAL=${#VIDEO_FILES[@]}
COUNT=0
FAILS=0

# --------------------------------------------------------------------
# --- 1. Loop por archivo ---
# --------------------------------------------------------------------
echo "🧪 Procesando $TOTAL videos desde '$VIDEODIR'..."
echo ""

for VIDEO in "${VIDEO_FILES[@]}"; do
  ((COUNT++))
  BASENAME=$(basename "$VIDEO")
  echo "[$COUNT/$TOTAL] ▶ Procesando: $BASENAME"

  ./scripts/parole.sh "$VIDEO" "$OUTDIR" $FORMAT_FLAG

  if [ $? -ne 0 ]; then
    echo "   ❌ Error procesando $BASENAME"
    ((FAILS++))
  else
    echo "   ✅ Completado"
  fi

  echo ""
done

# --------------------------------------------------------------------
# --- 2. Resumen final ---
# --------------------------------------------------------------------
SUCCESS=$((TOTAL - FAILS))
echo "🎉 Procesamiento finalizado: $SUCCESS / $TOTAL completados correctamente."
if [ "$FAILS" -gt 0 ]; then
  echo "⚠️  $FAILS archivos fallaron. Revisa los logs anteriores."
fi
