#!/usr/bin/env bash
# Instalador del entorno para el proyecto "parole"
# Crea entornos virtuales para Python y R, instala dependencias
# y gestiona la instalación de Praat (versión barren para Linux) si falta.

set -e  # salir si hay error
cd "$(dirname "${BASH_SOURCE[0]}")"

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

# Use the verified historical build, independently of system Praat.
bash scripts/install_praat.sh

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
    pip install -r "${PAROLE_PYTHON_REQUIREMENTS:-requirements_python.txt}"

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

