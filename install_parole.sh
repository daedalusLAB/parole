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
    # Detectar arquitectura. En Praat 7.x el asset de x86-64 cambió de nombre:
    # `..._linux-intel64...` existe hasta 6.4.30 y a partir de 7.0 es
    # `..._linux-x64v3...`. Se prueban los sufijos candidatos en orden en lugar de
    # fijar uno, porque el instalador tiene que seguir sirviendo en equipos con 6.x.
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
      ARCH_SUFFIXES="x64v3|intel64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      ARCH_SUFFIXES="arm64"
    else
      echo "❌ Arquitectura no soportada: $ARCH"
      exit 1
    fi

    # ─────────────────────────────────────────────────────────
    # Dónde está Praat. Los tarballs ya NO se sirven desde
    # https://www.fon.hum.uva.nl/praat/ (devuelven 404 incluso para la versión que
    # enlaza la propia página de descargas); ahora viven en las releases de GitHub:
    # https://github.com/praat/praat/releases/download/v7.0.02/praat7002_linux-x64v3-barren.tar.gz
    #
    # Se pregunta a la API de la última release en vez de buscar versión a versión:
    # el número `6436` no es monótono decodable (6.4.30 -> "6430", y 7.0.02 -> "7002"),
    # así que la antigua semilla + `+1` no puede reconstruir la etiqueta `vX.Y.ZZ`, y
    # de hecho la semilla quedó por encima del último 6.x (6.4.30), por lo que la
    # búsqueda ascendente no podía acertar nunca.
    #
    # Para entornos sin salida a api.github.com se puede saltar la descobierta:
    #   PRAAT_URL="https://github.com/praat/praat/releases/download/..." bash install_parole.sh
    if [[ -z "${PRAAT_URL:-}" ]]; then
      RELEASES_API="https://api.github.com/repos/praat/praat/releases/latest"
      echo "🔍 Consultando la última release de Praat (${ARCH_SUFFIXES})…"
      RELEASE_JSON=$(curl -sSL --max-time 30 -H "Accept: application/vnd.github+json" "$RELEASES_API" 2>/dev/null || true)
      if [[ -z "$RELEASE_JSON" ]]; then
        echo "❌ No se pudo consultar $RELEASES_API." >&2
        echo "   (red, proxy, o límite de la API de GitHub sin token: 60 peticiones/h por IP)." >&2
        echo '   Salida a mano: PRAAT_URL=<url del .tar.gz barren> bash '"$0" >&2
        exit 1
      fi
      RELEASE_TAG=$(printf '%s\n' "$RELEASE_JSON" \
        | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | head -n 1 | sed -E 's/.*"([^"]+)"$/\1/' || true)
      PRAAT_URL=$(printf '%s\n' "$RELEASE_JSON" \
        | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' \
        | sed -E 's/.*"(https[^"]+)"$/\1/' \
        | grep -E "linux-(${ARCH_SUFFIXES})-barren\.tar\.gz$" | head -n 1 || true)
      if [[ -z "$PRAAT_URL" ]]; then
        echo "❌ La release ${RELEASE_TAG:-desconocida} no trae un asset barren para $ARCH (sufijos probados: ${ARCH_SUFFIXES//|/, })." >&2
        echo "   Assets de Linux en esa release:" >&2
        printf '%s\n' "$RELEASE_JSON" \
          | grep -oE 'praat[0-9]+_linux[A-Za-z0-9._-]*\.tar\.gz' | sort -u | sed 's/^/     /' >&2
        echo '   Salida a mano: PRAAT_URL=<url> bash '"$0" >&2
        exit 1
      fi
    else
      echo "🔍 Usando la PRAAT_URL indicada a mano…"
    fi

    PRAAT_FILE=$(basename "$PRAAT_URL")
    LATEST_VERSION=$(printf '%s' "$PRAAT_FILE" | sed -E 's/^praat([0-9]+)_.*/\1/')
    echo "✅ Praat ${RELEASE_TAG:-$LATEST_VERSION}  →  $PRAAT_FILE"
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

    # (Antes este bloque reescribía su propia semilla PRAAT_VERSION con `sed -i $0`.
    #  Se elimina a propósito: era la causa del fallo. La semilla se quedó congelada
    #  en 6436 —por encima del último 6.x, 6.4.30— y al no poder reconstruir la
    #  etiqueta de la release a partir del número, la búsqueda ascendente devolvía
    #  100× 404. Descubrir la release en cada instalación es lo que falta.)

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

