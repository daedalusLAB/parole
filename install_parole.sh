#!/usr/bin/env bash
# Instalador del entorno para el proyecto "parole"
# Crea entornos virtuales para Python y R, instala dependencias
# y gestiona la instalación de Praat (versión barren para Linux) si falta.

set -e  # salir si hay error

########################################
# 0. Chequeo inicial de dependencias
########################################
echo "📋 Verificando dependencias del sistema..."

missing_deps=()

check_dep() {
  if command -v "$1" &> /dev/null; then
    echo "  ✔ $1 encontrado"
  else
    echo "  ❌ $1 NO encontrado"
    missing_deps+=("$1")
  fi
}

# Chequear herramientas clave
for dep in ffmpeg ffprobe Rscript; do
  check_dep "$dep"
done

# Praat: permitir versión local si existe en env/praat
if command -v praat &> /dev/null || [ -x env/praat/praat ]; then
  echo "  ✔ praat (global o local) encontrado"
else
  echo "  ❌ praat NO encontrado"
  missing_deps+=("praat")
fi

##############################################################################
# 1. Instalar Praat local (auto) ― con búsqueda de la versión más reciente
##############################################################################

if [[ ! $(command -v praat) ]]; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo ""
    echo "⚠️  'praat' no está instalado en el sistema."
    echo "   Se instalará localmente en env/praat (versión barren)."

    # ─────────────────────────────────────────────────────────
    # Detectar arquitectura
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
      ARCH_SUFFIX="linux-intel64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      ARCH_SUFFIX="linux-arm64"
    else
      echo "❌ Arquitectura no soportada: $ARCH"
      exit 1
    fi

    # ─────────────────────────────────────────────────────────
    # Semilla de versión y búsqueda incremental
    PRAAT_VERSION="6436"           # <–– se autovariará si hay una más alta
    SEARCH_LIMIT=100               # buscará hasta 100 versiones por delante
    LATEST_VERSION=""

    echo "🔍 Buscando la versión más reciente de Praat (${ARCH_SUFFIX})…"
    for ((i=0; i<=SEARCH_LIMIT; i++)); do
      CANDIDATE=$((PRAAT_VERSION + i))
      CANDIDATE_FILE="praat${CANDIDATE}_${ARCH_SUFFIX}-barren.tar.gz"
      CANDIDATE_URL="https://www.fon.hum.uva.nl/praat/${CANDIDATE_FILE}"

      # ¿existe la URL?  (–--fail = devuelve 22 si 404)
      if curl --head --silent --fail "$CANDIDATE_URL" > /dev/null; then
        LATEST_VERSION=$CANDIDATE
        PRAAT_FILE=$CANDIDATE_FILE
        PRAAT_URL=$CANDIDATE_URL
        break
      fi
    done

    if [[ -z "$LATEST_VERSION" ]]; then
      echo "❌ No se encontró ninguna versión válida tras $SEARCH_LIMIT intentos."
      exit 1
    fi

    echo "✅ Encontrada versión $LATEST_VERSION  →  $PRAAT_FILE"
    mkdir -p env/praat
    echo "🔽 Descargando..."
    curl -L "$PRAAT_URL" -o env/praat/praat.tar.gz

    echo "📦 Extrayendo..."
    tar -xzf env/praat/praat.tar.gz -C env/praat
    rm env/praat/praat.tar.gz

    # ─────────────────────────────────────────────────────────
    # Detectar binario y crear symlink estable
    BIN_CANDIDATE=$(find env/praat -maxdepth 1 -type f -executable -name "praat*" | head -n 1)
    if [[ -n "$BIN_CANDIDATE" ]]; then
      chmod +x "$BIN_CANDIDATE"
      ln -sf "$(basename "$BIN_CANDIDATE")" env/praat/praat
      echo "✅ Binario enlazado como env/praat/praat → $(basename "$BIN_CANDIDATE")"
    else
      echo "⚠️  No se encontró binario válido tras la extracción."
    fi

    # ─────────────────────────────────────────────────────────
    # Autopersistencia de la versión (solo si cambió)
    if [[ "$LATEST_VERSION" != "$PRAAT_VERSION" ]]; then
      echo "📝 Actualizando versión por defecto en el propio script a $LATEST_VERSION…"
      # $0 es la ruta del script en ejecución
      sed -i -E "s/^PRAAT_VERSION=\"[0-9]+\"/PRAAT_VERSION=\"${LATEST_VERSION}\"/" "$0" || \
        echo "⚠️  No se pudo reescribir la versión en $0 (permiso denegado)."
    fi

    echo "🎉 Praat $LATEST_VERSION instalado en env/praat/"
  else
    echo "ℹ️  Sistema no Linux-GNU: instala Praat manualmente."
  fi
else
  echo "✔  'praat' ya está disponible en el sistema; se omite instalación."
fi

########################################
# 2. Confirmar si continuar si hay dependencias faltantes
########################################
if [ ${#missing_deps[@]} -gt 0 ]; then
  echo ""
  echo "⚠️ Faltan las siguientes dependencias del sistema:"
  printf '   - %s\n' "${missing_deps[@]}"
  echo ""
  read -p "¿Quieres continuar con la instalación de entorno Python y R de todas formas? [y/N]: " cont
  if [[ "$cont" != "y" && "$cont" != "Y" ]]; then
    echo "🛑 Instalación cancelada."
    exit 1
  fi
fi

echo ""
echo "✅ Continuando con la instalación de entornos virtuales..."
echo ""

########################################
# 3. Reinstalar / Crear entorno Python
########################################
REINSTALL_PY=false
if [ -d env/pyenv ]; then
  echo "⚠️ Se ha detectado un entorno Python existente en 'env/pyenv'."
  read -p "¿Deseas reinstalar (borrar y crear de nuevo) el entorno de Python? [y/N]: " ans_py
  if [[ "$ans_py" == "y" || "$ans_py" == "Y" ]]; then
    REINSTALL_PY=true
    echo "🗑 Borrando entorno Python existente..."
    rm -rf env/pyenv
  fi
fi

if [ ! -f requirements_python.txt ]; then
  echo "❌ No se encontró 'requirements_python.txt'"
  read -p "¿Quieres continuar sin instalar dependencias de Python? [y/N]: " py_skip
  if [[ "$py_skip" != "y" && "$py_skip" != "Y" ]]; then
    echo "🛑 Instalación cancelada."
    exit 1
  fi
else
  # Si REINSTALL_PY = true o no existía env/pyenv
  if [ "$REINSTALL_PY" = true ] || [ ! -d env/pyenv ]; then
    echo "🔧 Creando entorno virtual de Python en env/pyenv..."
    python3 -m venv env/pyenv
    source env/pyenv/bin/activate
    pip install --upgrade pip

    echo "📦 Instalando dependencias desde requirements_python.txt..."
    pip install -r requirements_python.txt

    deactivate
    echo "✅ Entorno Python creado e instalado correctamente."
  else
    echo "✅ Manteniendo el entorno Python existente en env/pyenv"
    echo "   (Si quieres reinstalarlo, vuelve a lanzar este script y elige 'y')"
  fi
fi

########################################
# 4. Reinstalar / Crear entorno R
########################################
REINSTALL_R=false
if [ -d env/Rlibs ]; then
  echo "⚠️ Se ha detectado un directorio 'env/Rlibs' con librerías R existentes."
  read -p "¿Deseas reinstalar (borrar y crear de nuevo) las librerías R? [y/N]: " ans_r
  if [[ "$ans_r" == "y" || "$ans_r" == "Y" ]]; then
    REINSTALL_R=true
    echo "🗑 Borrando librerías R existentes..."
    rm -rf env/Rlibs
  fi
fi

# Si existe .Renviron y se va a reinstalar R, lo borramos
if [ -f .Renviron ] && [ "$REINSTALL_R" = true ]; then
  echo "🗑 Borrando .Renviron existente..."
  rm -f .Renviron
fi

if [ "$REINSTALL_R" = true ] || [ ! -d env/Rlibs ]; then
  echo ""
  echo "📁 Creando carpeta para librerías R en env/Rlibs..."
  mkdir -p env/Rlibs

  # Crear .Renviron local
  echo "R_LIBS_USER=${PWD}/env/Rlibs" > .Renviron
  echo "✅ Archivo .Renviron creado con R_LIBS_USER=${PWD}/env/Rlibs"

  echo "📦 Instalando paquetes R necesarios..."
  Rscript -e 'install.packages(c("arrow", "data.table", "tidyverse"), repos="https://cloud.r-project.org", lib="env/Rlibs")'

  echo "✅ Librerías R instaladas correctamente en env/Rlibs"
else
  echo "✅ Manteniendo las librerías R existentes en env/Rlibs"
  echo "   (Si quieres reinstalarlas, vuelve a lanzar este script y elige 'y')"
fi

echo ""
echo "🎉 Instalación completada. Todo listo para usar ./scripts/parole.sh"

