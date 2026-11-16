#!/usr/bin/env bash
#

echo "🔊 PAROLE: Automatic Speech Prosody Extraction from Video"
echo "Copyright (C) 2025 Brian Herreño Jiménez & Cristóbal Pagán Cánovas"
echo "License: GNU GPL v3 - see LICENSE file or https://www.gnu.org/licenses/gpl-3.0.html"
echo ""
echo "This program is free software: you can redistribute it and/or modify"
echo "it under the terms of the GNU General Public License as published by"
echo "the Free Software Foundation, either version 3 of the License, or"
echo "(at your option) any later version."
echo ""

# Uso: ./parole.sh VIDEO.mp4 OUTPUT_DIR [--parquet]
#
# Este script hace secuencialmente:
#   1) Preparación (directorios, nombres de archivo)
#   2) Extrae audio (44.1 kHz para Praat, 16 kHz para Silero)
#   3) Silero VAD, 4) Praat, 5) ffprobe → (paralelizados)
#   6) Rscript (interpolación final)
#   7) Limpieza de intermedios

set -e  # Salir ante cualquier error

# --------------------------------------------------------------------
# --- 0. Validar argumentos ---
# --------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "Uso: $0 VIDEO.mp4 OUTPUT_DIR [--parquet]"
  exit 1
fi

VIDEO="$1"
OUTDIR="$2"
OUTPUT_FORMAT="csv"
if [ "$3" == "--parquet" ]; then
  OUTPUT_FORMAT="parquet"
fi

# --------------------------------------------------------------------
# --- Determinar rutas absolutas y base del proyecto ---
# --------------------------------------------------------------------
# BASEDIR: un nivel arriba de la carpeta 'scripts/' donde se encuentra este script
BASEDIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"

# Asegurar que VIDEO y OUTDIR sean rutas absolutas
VIDEO="$(realpath "$VIDEO")"
OUTDIR="$(realpath "$OUTDIR")"

# Si Praat local existe en env/praat, lo añadimos al PATH
if [ -x "${BASEDIR}/env/praat/praat" ]; then
  export PATH="${BASEDIR}/env/praat:$PATH"
fi

# --------------------------------------------------------------------
# --- 1. Preparar nombres de archivo ---
# --------------------------------------------------------------------
BASENAME="$(basename "$VIDEO" .mp4)"
FINALDIR="${OUTDIR}/${BASENAME}"
mkdir -p "$FINALDIR"

rate=$(ffprobe -i "$VIDEO" -select_streams a:0 -show_entries stream=sample_rate -v quiet -of csv="p=0") || true
if [ -z "$rate" ]; then
  echo "⚠️  No se pudo detectar la frecuencia de muestreo con ffprobe. Se usará 44100 Hz por defecto."
  rate=44100
fi
echo "Frecuencia de muestreo detectada (o fallback): ${rate} Hz"

AUDIOWAV="${FINALDIR}/${BASENAME}_${rate}Hz.wav"
AUDIO16K="${FINALDIR}/${BASENAME}_16kHz.wav"
FRAMESCSV="${FINALDIR}/${BASENAME}_frame_timestamps.csv"

if [ "$OUTPUT_FORMAT" == "parquet" ]; then
  OUTFILE_NAME="${BASENAME}_prosody.parquet"
else
  OUTFILE_NAME="${BASENAME}_prosody.csv"
fi

# Normalizar rutas absolutas
FINALDIR="$(realpath "$FINALDIR")"
AUDIOWAV="$(realpath --canonicalize-missing "$AUDIOWAV")"
AUDIO16K="$(realpath --canonicalize-missing "$AUDIO16K")"
FRAMESCSV="$(realpath --canonicalize-missing "$FRAMESCSV")"

# Scripts auxiliares
PRAAT_SCRIPT="${BASEDIR}/scripts/extract_prosody.praat"
RSCRIPT="${BASEDIR}/scripts/process_prosody.R"
SILERO_PY="${BASEDIR}/scripts/silero_vad_runner.py"
PROVENANCE_PY="${BASEDIR}/scripts/write_provenance.py"
PRAAT_BIN="$(command -v praat)"
PYTHON_BIN="${BASEDIR}/env/pyenv/bin/python"
if [ ! -x "$PYTHON_BIN" ]; then PYTHON_BIN="$(command -v python3)"; fi
"$PYTHON_BIN" "$PROVENANCE_PY" start --repo "$BASEDIR" --praat "$PRAAT_BIN" \
  --script "$PRAAT_SCRIPT" --output "${FINALDIR}/${OUTFILE_NAME}"


# --------------------------------------------------------------------
# --- 2. Extraer audio (secuencial) ---
# --------------------------------------------------------------------
echo "[Paso 2] Extrayendo audio a rate=$rate Hz → $AUDIOWAV"
ffmpeg -i "$VIDEO" -acodec pcm_s16le -ac 1 -ar "$rate" -y "$AUDIOWAV"

echo "[Paso 2b] Extrayendo audio 16 kHz para Silero → $AUDIO16K"
ffmpeg -i "$VIDEO" -acodec pcm_s16le -ac 1 -ar 16000 -y "$AUDIO16K"

# Verificar que se crearon correctamente
if [ ! -s "$AUDIOWAV" ]; then
  echo "❌ El archivo $AUDIOWAV no se generó correctamente."
  exit 1
fi
if [ ! -s "$AUDIO16K" ]; then
  echo "❌ El archivo $AUDIO16K no se generó correctamente."
  exit 1
fi

# --------------------------------------------------------------------
# --- 3. Silero, 4. Praat, 5. ffprobe timestamps (Paralelizado) ---
# --------------------------------------------------------------------
(
  # PASO 3: SILERO VAD
  echo "[Paso 3] Ejecutando Silero (opcional)..."
  if [ -f "$SILERO_PY" ]; then
    echo "Activando entorno Python..."
    source "${BASEDIR}/env/pyenv/bin/activate" 2>/dev/null || echo "⚠️  No se pudo 'activate'. Asegura tu env."
    
    echo "🎙️  Ejecutando Silero sobre $AUDIO16K"
    CSVOUT="${AUDIO16K%.wav}_silero_segments.csv"
    python3 "$SILERO_PY" "$AUDIO16K" "$FINALDIR"
    
    deactivate || true
    
    if [ -f "$CSVOUT" ]; then
      echo "✅ Silero OK. Segmentos generados: $CSVOUT"
    else
      echo "⚠️  Silero no generó el CSV esperado. Revisa logs."
    fi
  else
    echo "⚠️  $SILERO_PY no encontrado. Omitiendo VAD."
  fi
) &
VAD_PID=$!

(
  # PASO 4: PRAAT
  echo "[Paso 4] Ejecutando Praat → $AUDIOWAV"
  if ! command -v praat &>/dev/null; then
    echo "❌ 'praat' no está en PATH. Instálalo o ajusta la ruta."
    exit 1
  fi

  if [ ! -f "$PRAAT_SCRIPT" ]; then
    echo "❌ No se encontró $PRAAT_SCRIPT."
    exit 1
  fi

  # Chequear WAV
  if [ ! -s "$AUDIOWAV" ]; then
    echo "❌ WAV para Praat no existe o es 0 bytes: $AUDIOWAV"
    exit 1
  fi
  
  "$PRAAT_BIN" --run "$PRAAT_SCRIPT" "$AUDIOWAV" "$FINALDIR"
) &
PRAAT_PID=$!

(
	  # PASO 5: TIMESTAMPS (ffprobe)
  echo "[Paso 5] Extrayendo timestamps con ffprobe → $FRAMESCSV"
  ffprobe -v error -select_streams v:0 -show_entries frame=pts_time \
    -of csv=p=0 "$VIDEO" |
  awk 'BEGIN{print "frame_id,frame_timestamp"} {printf "%d,%.6f\n", NR-1, $1}' > "$FRAMESCSV"

  if [ ! -s "$FRAMESCSV" ]; then
    echo "❌ Error: no se generó $FRAMESCSV"
    exit 1
  fi
) &
FRAMES_PID=$!
# VAD remains optional; Praat and timestamps are required.
wait "$VAD_PID" || echo "⚠️ Silero failed; continuing without VAD."
wait "$PRAAT_PID"
wait "$FRAMES_PID"

# --------------------------------------------------------------------
# --- 6. Ejecutar Rscript (process_prosody.R) ---
# --------------------------------------------------------------------
echo "[Paso 6] Ejecutando Rscript para generar archivo final: $OUTFILE_NAME"

if [ ! -f "$RSCRIPT" ]; then
  echo "❌ No se encontró $RSCRIPT."
  exit 1
fi
if ! command -v Rscript &>/dev/null; then
  echo "❌ 'Rscript' no está en PATH. Instálalo o ajusta la ruta."
  exit 1
fi

R_LIBS_USER="${BASEDIR}/env/Rlibs" Rscript "$RSCRIPT" "$FINALDIR" "$OUTFILE_NAME"
"$PYTHON_BIN" "$PROVENANCE_PY" complete --repo "$BASEDIR" --praat "$PRAAT_BIN" \
  --script "$PRAAT_SCRIPT" --output "${FINALDIR}/${OUTFILE_NAME}"
echo "✅ Rscript completado. Archivo final generado: $OUTFILE_NAME"

# --------------------------------------------------------------------
# --- 7. Limpieza de archivos intermedios ---
# --------------------------------------------------------------------
echo "[Paso 7] Limpiando archivos intermedios en $FINALDIR..."
rm -f "${FINALDIR}"/*.Pitch \
      "${FINALDIR}"/*.Intensity \
      "${FINALDIR}"/*.Formant \
      "${FINALDIR}"/*.Harmonicity \
      "${FINALDIR}"/*.PointProcess \
      "${FINALDIR}"/*.wav \
      "${FINALDIR}"/*_frame_timestamps.csv \
      "${FINALDIR}"/*_silero_segments.csv 2>/dev/null || true

echo "✅ Proceso COMPLETADO. Archivo final: ${FINALDIR}/${OUTFILE_NAME}"

