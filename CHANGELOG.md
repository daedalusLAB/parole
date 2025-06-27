## 1.1.1  ·  2025-06-20

### Fixed / Corregido · 2025-06-27

| EN                                                                                                                                                                                                    | ES                                                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Frame 0 preserved in prosody pipeline** – Removed hard-coded deletion of the first row from `*_frame_timestamps.csv` in `process_prosody.R`. With FFmpeg 7.1+, this workaround is no longer needed. | **Preservación del frame 0 en la tubería prosódica** – Se eliminó el borrado forzado de la primera fila de `*_frame_timestamps.csv` en `process_prosody.R`. Con FFmpeg 7.1+, esta solución ya no es necesaria. |

### Fixed / Corregido · 2025-06-23

| EN                                                                                                                                                                                                                                        | ES                                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Timestamp field migrated to `pts_time`** – The `ffprobe` call in `parole.sh` now uses `pts_time` instead of `pkt_pts_time` to restore stability under FFmpeg 7.1+, ensuring compatibility across formats and preventing silent failure. | **Campo de marca de tiempo migrado a `pts_time`** – La llamada a `ffprobe` en `parole.sh` ahora utiliza `pts_time` en lugar de `pkt_pts_time` para recuperar estabilidad en FFmpeg 7.1+, garantizando compatibilidad entre formatos y evitando fallos silenciosos. |

### Fixed / Corregido · 2025-06-20

| EN                                                                                                                                                                                                                                                   | ES                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Robust timestamp extraction** – The `ffprobe` call in `parole.sh` has been rewritten to emit a clean list of `pkt_pts_time` values, eliminating empty or malformed lines in `*_frame_timestamps.csv`.                                              | **Extracción robusta de marcas de tiempo** – Se ha reescrito la llamada a `ffprobe` en `parole.sh` para que genere una lista limpia de `pkt_pts_time`, evitando líneas vacías o mal formateadas en `*_frame_timestamps.csv`.                                                |
| **Installer steps restored** – `install_parole.sh` now reliably (re)creates the Python virtual-env `env/pyenv` and installs dependencies from `requirements_python.txt`; the R library folder `env/Rlibs` is likewise re-initialised when requested. | **Pasos del instalador restaurados** – `install_parole.sh` vuelve a (re)crear correctamente el entorno virtual Python `env/pyenv` e instala dependencias desde `requirements_python.txt`; la carpeta de librerías R `env/Rlibs` también se reinicializa cuando se solicita. |

---

Previous versions are tracked in the project’s Git history.
Las versiones anteriores se encuentran en el historial Git del proyecto.

