[➡️ English Version](#english)

<p align="center">
  <img src="images/logo_parole.png" alt="PAROLE logo" width="50%">
</p>

<p align="center">
  <strong style="font-size: 2em;">PAROLE</strong><br>
  <span style="font-size: 1.2em;">Extracción automática de prosodia del habla</span>
</p>

<p align="center">
<a href="https://doi.org/10.5281/zenodo.15522925">
  <img src="https://zenodo.org/badge/964120256.svg" alt="DOI">
  </a>
  <a href="https://github.com/daedalusLAB/parole/actions/workflows/parole-ci.yml">
    <img src="https://github.com/daedalusLAB/parole/actions/workflows/parole-ci.yml/badge.svg?branch=main" alt="PAROLE CI — live main status">
  </a>
</p>

> **Consulta** [CHANGELOG.md](./CHANGELOG.md) **para ver los cambios recientes.**

## 🛠️ Descripción

**PAROLE** es un pipeline automatizado para la extracción de información prosódica del habla (pitch, intensidad, formantes, harmonicidad, y detección de actividad vocal mediante VAD) desde vídeos. Utiliza herramientas estándar como Praat, Python, R y Silero-VAD, proporcionando resultados en formatos CSV o Parquet.

---


## 📘 Manual técnico

Puedes consultar el manual completo de PAROLE en el siguiente enlace:

📄 [Manual técnico (PDF, español)](./_book/Parole--Ecosistema-Funcional.pdf)

Este documento incluye fundamentos teóricos, justificación metodológica, y detalles técnicos sobre la arquitectura, herramientas, scripts y formatos de salida.


## 📁 Estructura del Proyecto

```
├── data
│   └── videos
│       ├── video_ejemplo1.mp4
│       └── video_ejemplo2.mp4
├── images 
│   └── logo_parole.png
├── install_parole.sh
├── requirements_python.txt
├── resultados
│   └── video_ejemplo1
│       ├── video_ejemplo1_prosody.csv
│       └── video_ejemplo1_prosody.parquet
└── scripts
    ├── extract_prosody.praat
    ├── parole_batch.sh
    ├── parole.sh
    ├── process_prosody.R
    └── silero_vad_runner.py
```

---

## ⚙️ Instalación

Ejecuta en una terminal desde la raíz del proyecto:

```bash
bash install_parole.sh
```

Esto creará los entornos de Python y R necesarios, instalará Praat (versión barren) localmente y configurará todas las dependencias automáticamente.

---

## 🚀 Ejecución

### Procesar un único vídeo

```bash
./scripts/parole.sh data/videos/tu_video.mp4 resultados/ --parquet
```

### Procesar múltiples vídeos (batch)

```bash
./scripts/parole_batch.sh data/videos/ resultados/ --parquet
```

---

## 📖 Dependencias clave

Este proyecto requiere las siguientes herramientas y librerías en distintos entornos:

- **Praat** — Interfaz de línea de comandos (CLI), incluye la versión *barren* utilizada para la extracción prosódica  
- **FFmpeg / FFprobe** — Para la gestión de audio/vídeo y alineación de timestamps

### 🐍 Python

- [`torch`](https://pytorch.org/) — Librería principal de deep learning usada por Silero VAD  
- [`torchaudio`](https://pytorch.org/audio/stable/) — Utilidades de procesamiento de audio para PyTorch  
- [`pandas`](https://pandas.pydata.org/) — Manipulación y gestión de datos  

### 📦 R

- [`arrow`](https://cran.r-project.org/package=arrow) — Usado para guardar los datos prosódicos finales en formato `.parquet`  



---

## 🔁 GitHub Actions

Este repositorio cuenta con un test automático en GitHub Actions que verifica:

- Instalación del entorno completo (Python, R, Praat)
- Ejecución del script `parole.sh` sobre un vídeo de prueba
- Verificación del archivo de salida en `.parquet`

Para más detalles, consulta el archivo [`parole-ci.yml`](.github/workflows/parole-ci.yml).

---

## 💬 Contactos

- **Soporte técnico:** [Brian Herreño Jiménez](mailto:brian.herreno@um.es)
- **Información del proyecto MULTIFLOW:** [Cristóbal Pagán Cánovas](mailto:cpcanovas@um.es)

---

## 📜 Licencia

Este proyecto se distribuye bajo la licencia [GPL-3](https://www.gnu.org/licenses/gpl-3.0.html).

---

## 📌 Autoría y financiación

**PAROLE** es un artefacto desarrollado por Daedalus Lab bajo el proyecto MULTIFLOW, financiado por el Ministerio de Ciencia, Innovación y Universidades de España.

---

<a id="english"></a>

[➡️ Versión en Español](#parole-extracción-automática-de-prosodia-del-habla)

# 📌 PAROLE: Automatic Speech Prosody Extraction

> **See** [CHANGELOG.md](./CHANGELOG.md) **for the latest fixes.**  

## 🛠️ Description

**PAROLE** is an automated pipeline for extracting speech prosodic information (pitch, intensity, formants, harmonicity, and Voice Activity Detection via VAD) from videos. It leverages standard tools like Praat, Python, R, and Silero-VAD, providing results in CSV or Parquet formats.

---

📘 A technical manual (in Spanish) is available here: [Parole--Ecosistema-Funcional.pdf](./_book/Parole--Ecosistema-Funcional.pdf)


## 📁 Project Structure

```
├── data
│   └── videos
│       ├── video_ejemplo1.mp4
│       └── video_ejemplo2.mp4
├── images
│   └── logo_parole.png
├── install_parole.sh
├── requirements_python.txt
├── resultados
│   └── video_ejemplo1
│       ├── video_ejemplo1_prosody.csv
│       └── video_ejemplo1_prosody.parquet
└── scripts
    ├── extract_prosody.praat
    ├── parole_batch.sh
    ├── parole.sh
    ├── process_prosody.R
    └── silero_vad_runner.py
```

---

## ⚙️ Installation

Run from a terminal at the project's root:

```bash
bash install_parole.sh
```

This will set up necessary Python and R environments, install Praat (barren version) locally, and automatically configure all dependencies.

---

## 🚀 Usage

### Single video processing

```bash
./scripts/parole.sh data/videos/your_video.mp4 resultados/ --parquet
```

### Batch video processing

```bash
./scripts/parole_batch.sh data/videos/ resultados/ --parquet
```

---
## 📖 Key Dependencies

This project requires the following tools and libraries across different environments:

- **Praat** — Command-line interface (CLI), includes the *barren* version used for prosodic extraction  
- **FFmpeg / FFprobe** — For audio/video alignment and timestamp management

### 🐍 Python

- [`torch`](https://pytorch.org/) — Core deep learning library used by Silero VAD  
- [`torchaudio`](https://pytorch.org/audio/stable/) — Audio processing utilities for PyTorch  
- [`pandas`](https://pandas.pydata.org/) — Data handling and manipulation  

### 📦 R

- [`arrow`](https://cran.r-project.org/package=arrow) — Used to write the final prosodic data as `.parquet` files  


---

## 🔁 GitHub Actions

This repository includes an automated test in GitHub Actions that checks:

- Installation of the full environment (Python, R, Praat)
- Execution of the `parole.sh` script on a test video
- Verification of the `.parquet` output file


For more details, see the [`parole-ci.yml`](.github/workflows/parole-ci.yml) file.

---

## 💬 Contacts

- **Technical support:** [Brian Herreño Jiménez](mailto:brian.herreno@um.es)
- **MULTIFLOW project information:** [Cristóbal Pagán Cánovas](mailto:cpcanovas@um.es)

---

## 📜 License

This project is distributed under the [GPL-3 License](https://www.gnu.org/licenses/gpl-3.0.html).

---

## 📌 Authorship and Funding

**PAROLE** is an artifact developed by Daedalus Lab as part of the MULTIFLOW project, funded by the Ministry of Science, Innovation, and Universities of Spain.


## Reproducibilidad y validación / Reproducibility and validation

**ES:** El instalador fija y verifica **Praat barren 6.4.60**, obtenido de la [release histórica oficial](https://github.com/praat/praat.github.io/releases/tag/v6.4.60), y utiliza el binario local aunque exista otro Praat en el sistema. Cada CSV o Parquet se acompaña de un archivo `.provenance.json` con la versión ejecutada, el commit de Parole (o `null` si no hay Git), el estado de cambios locales, la fecha UTC y los parámetros leídos directamente de `scripts/extract_prosody.praat`. El JSON indica `running` durante el procesamiento y `complete` solo tras generar el resultado; incluye hashes del script y del resultado. No altera el esquema de datos ni el método de interpolación.

**EN:** The installer pins and verifies **Praat barren 6.4.60** from the [official historical release](https://github.com/praat/praat.github.io/releases/tag/v6.4.60), using the local binary independently of system Praat. Each CSV or Parquet has a `.provenance.json` sidecar recording the actual Praat version, Parole commit (or `null` without Git), working-tree state, UTC timestamps and parameters read directly from `scripts/extract_prosody.praat`. Its status is `running` during processing and `complete` only after producing the result; it also records script and output hashes. The data schema and upstream interpolation method are unchanged.

### Synthetic CI / CI sintético

CI installs PAROLE, executes the existing interpolation regression tests, and processes the [synthetic English fixture](tests/fixtures/synthetic_en.wav). Its [manifest](tests/fixtures/synthetic_en.json) records the input checksum and timeline. Checks cover frame alignment, known tones, a chirp, CPU voice activity detection and the provenance sidecar. Only synthetic results and JSON reports are uploaded. This is a reproducible smoke test, not a human-speech accuracy benchmark. The badge above reports the actual status of the `main` workflow.

CI instala PAROLE, ejecuta las pruebas de interpolación existentes y procesa el ejemplo sintético en inglés. Comprueba fotogramas, tonos conocidos, un barrido, VAD en CPU y el JSON de procedencia. Solo publica resultados sintéticos e informes JSON. El distintivo muestra el estado real del workflow de `main`.

Optional local CPU VAD / VAD local opcional en CPU:

```bash
env/pyenv/bin/python -m pip install -r requirements_silero_cpu.txt
env/pyenv/bin/python -m pip install -r requirements_silero_local.txt
```

CI selects CPU dependencies during installation with `PAROLE_PYTHON_REQUIREMENTS=requirements_silero_cpu.txt`; ordinary installations retain `requirements_python.txt`. Silero reads normalized WAV using SoundFile. The first model download needs internet; the model still follows Torch Hub's `master` reference, and synthetic CI records the model checksum.

## Contributors / Personas colaboradoras

- [Brian Herreño Jiménez](https://github.com/bHerreno)
- [Raúl Sánchez](https://github.com/raul-agent)

**Research development:** Brian Herreño Jiménez contributes to PAROLE and develops research work in [bHerreno/parole](https://github.com/bHerreno/parole). Changes are proposed to this repository through pull requests for review and approval.

**Desarrollo de investigación:** Brian Herreño Jiménez colabora en PAROLE y desarrolla su investigación en su fork. Los cambios se proponen a este repositorio mediante pull requests para revisión y aprobación.
