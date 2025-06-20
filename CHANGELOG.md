# 📜 CHANGELOG / HISTORIAL DE CAMBIOS

All notable changes to **PAROLE** are documented in this file.

---

## 2.1.0  ·  2025‑06‑20

### Fixed / Corregido

| EN                                                                                                                                                                                                                                                   | ES                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Robust timestamp extraction** – The `ffprobe` call in `parole.sh` has been rewritten to emit a clean list of `pkt_pts_time` values, eliminating empty or malformed lines in `*_frame_timestamps.csv`.                                              | **Extracción robusta de marcas de tiempo** – Se ha reescrito la llamada a `ffprobe` en `parole.sh` para que genere una lista limpia de `pkt_pts_time`, evitando líneas vacías o mal formateadas en `*_frame_timestamps.csv`.                                                |
| **Installer steps restored** – `install_parole.sh` now reliably (re)creates the Python virtual‑env `env/pyenv` and installs dependencies from `requirements_python.txt`; the R library folder `env/Rlibs` is likewise re‑initialised when requested. | **Pasos del instalador restaurados** – `install_parole.sh` vuelve a (re)crear correctamente el entorno virtual Python `env/pyenv` e instala dependencias desde `requirements_python.txt`; la carpeta de librerías R `env/Rlibs` también se reinicializa cuando se solicita. |

---

Previous versions are tracked in the project’s Git history.

Las versiones anteriores se encuentran en el historial Git del proyecto.

