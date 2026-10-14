#!/usr/bin/env python3
"""Comprueba cómo aterriza la prosodia de Praat en la rejilla de fotogramas.

`process_prosody.R` recibe pistas de Praat a 1-10 ms y una rejilla de fotogramas a
~33 ms. Lo que NO puede hacer es fabricar valores donde Praat no midió, y eso es
justamente lo que hacía: una única spline cúbica sobre TODOS los puntos válidos,
evaluados en todos los fotogramas. Con `splinefun` no se puede apagar la
extrapolacion (no admite el argumento `extrapolation`: probado, `unused argument`),
así que el polinomio pasaba por el silencio y por el borde del clip.

Medido sobre un clip real (CNN Newsroom, 5,2 s) para fijar las reglas:

  * Praat marca el silencio con **frecuencia = 0** (el candidato "mute"), no con
    `nCandidates = 0`. En ese clip: 1715 de 5129 frames (33,4 %) son mute.
  * El suelo del HNR por correlación cruzada de Praat es **-200 dB**: en silencio
    harmonicity vale -200, que es una medida legítima ("sin periodicidad"). Lo que
    no existe es un valor POR DEBAJO de -200: eso solo lo produce la spline.
  * Con `To Formant (burg): 0.001, 5, 5500` ninguna frecuencia medida puede pasar de
    5500 Hz. En nuestros datos había una F5 de 29.144.321 Hz: 5300 veces el techo.
  * Rachas de silencio del pitch: mediana 70 ms, p90 238 ms, max 359 ms. Un hueco de
    <= 0,1 s (~3 fotogramas) sigue dentro de la misma frase; por encima de ahí hay
    silencio de verdad y el valor tiene que ser NULL.

Casos:
  A. en el silencio largo no hay pitch (antes: numero en todos los fotogramas)
  B. fuera del rango seguido por la pista no hay NINGUNA señal (antes: extrapolaba)
  C. todo valor publicado cae dentro del rango de su propia pista (antes: no)
  D. el 0 de Praat no se publica como valor
  E. un hueco corto dentro de una frase SÍ tiene valor, y es un pitch real (no pasarse a NULL,
     y tampoco publicar el 0 del mute)
  F. una fila por fotograma, siempre (el contrato con quien consume el Parquet)
  G. `voice_present` existe y coincide con donde hay pitch medido
  H. la intensidad no se NULL-ea de más: donde Praat la midió, sigue ahí
"""
import os
import subprocess
import sys
import tempfile

import pandas as pd

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RSCRIPT = os.path.join(REPO, "scripts", "process_prosody.R")
ALINEADOR = os.path.join(REPO, "scripts", "prosody_align.R")

FPS = 29.97
DUR = 6.4                      # el clip dure más que las pistas: los últimos frames no tienen pista
PITCH_PASO = 0.005
PITCH_X1 = 0.025
PITCH_FIN = 6.00               # la pista de pitch acaba aqui
INT_FIN = 5.90
HARM_FIN = 5.80
FORM_FIN = 5.70
SIL_INCIO, SIL_FIN = 1.00, 5.00     # silencio largo (4 s)
AGUJERO_INCIO, AGUJERO_FIN = 0.500, 0.540   # hueco corto dentro de la frase 1
PITCH_MIN, PITCH_MAX = 60.0, 150.0  # el rango real de la pista de pitch de este fixture
SUELO_HARM = -200.0


def _times(x1, fin, paso):
    n = int((fin - x1) / paso) + 1
    return [x1 + i * paso for i in range(n)]


def escribir_pitch(dir_):
    """`.Pitch` en el formato largo real de Praat: el silencio es frequency = 0."""
    lineas = ["File type = \"ooTextFile\"", "Object class = \"Pitch 1\"", "",
              "xmin = 0", f"xmax = {PITCH_FIN}", f"nx = 0", f"dx = {PITCH_PASO}",
              f"x1 = {PITCH_X1}", "ceiling = 600", "maxnCandidates = 1", "", "frames []: "]
    tiempos = _times(PITCH_X1, PITCH_FIN, PITCH_PASO)
    for i, t in enumerate(tiempos, start=1):
        frec = 150.0 if t < 2.0 else (110.0 if t < 5.6 else 70.0)
        if SIL_INCIO <= t <= SIL_FIN or AGUJERO_INCIO <= t <= AGUJERO_FIN:
            frec = 0.0
        lineas += [f"    frames [{i}]:", "        intensity = 0.6423305178420518",
                   "        nCandidates = 1", "        candidates []: ",
                   "            candidates [1]:", f"                frequency = {frec}",
                   "                strength = 0.7110126431895019"]
    with open(os.path.join(dir_, "pitch.Pitch"), "w") as f:
        f.write("\n".join(lineas) + "\n")


def escribir_matriz(dir_, nombre, extension, x1, fin, paso, valor):
    """`.Intensity` / `.Harmonicity`: `z [] []:` y luego una linea `z [1] [k] = v` por muestra."""
    tiempos = _times(x1, fin, paso)
    lineas = ["File type = \"ooTextFile\"", "Object class = \"Function 1\"", "",
              "xmin = 0", f"xmax = {fin}", "dx = %r" % paso, "x1 = %r" % x1,
              "ymin = 1", "ymax = 1", "ny = 1", "dy = 1", "y1 = 1", "", "z [] []: ",
              "    z [1]:"]
    for k, t in enumerate(tiempos, start=1):
        v = valor(t)
        lineas.append(f"        z [1] [{k}] = {v}")
    with open(os.path.join(dir_, nombre + extension), "w") as f:
        f.write("\n".join(lineas) + "\n")


def escribir_formantes(dir_):
    """`.Formant` real: `formant []:` y despues `formant [n]:` con frequency/bandwidth."""
    tiempos = _times(PITCH_X1, FORM_FIN, PITCH_PASO)
    lineas = ["File type = \"ooTextFile\"", "Object class = \"Formant 1\"", "",
              "xmin = 0", f"xmax = {FORM_FIN}", f"dx = {PITCH_PASO}", f"x1 = {PITCH_X1}",
              "maxnFormants = 5", "", "frames []: "]
    for i, t in enumerate(tiempos, start=1):
        lineas += [f"    frames [{i}]:", "        intensity = 0.010428726448440255",
                   "        numberOfFormants = 2", "        formant []:"]
        for n, freq in ((1, 500.0), (2, 1500.0)):
            lineas += [f"            formant [{n}]:", f"                frequency = {freq}",
                       "                bandwidth = 80.0"]
    with open(os.path.join(dir_, "formants.Formant"), "w") as f:
        f.write("\n".join(lineas) + "\n")


def escribir_entrada(dir_):
    with open(os.path.join(dir_, "clip_frame_timestamps.csv"), "w") as f:
        f.write("frame_id,frame_timestamp\n")
        n = int(DUR * FPS)
        for i in range(n):
            f.write(f"{i},{i / FPS:.6f}\n")
    with open(os.path.join(dir_, "clip_silero_segments.csv"), "w") as f:
        f.write("start,end\n0.10,1.00\n5.00,6.00\n")
    return int(DUR * FPS)


def ejecutar(dir_):
    env = dict(os.environ, R_LIBS_USER=os.path.join(REPO, "R_libs"))
    r = subprocess.run(["Rscript", RSCRIPT, dir_, "clip_prosody.parquet"],
                       cwd=dir_, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"Rscript fallo ({r.returncode}): {r.stderr.strip()[-400:]}")
    return pd.read_parquet(os.path.join(dir_, "clip_prosody.parquet"))


def en(t, df):
    """La fila del fotograma cuyo timestamp cae mas cerca de t."""
    return df.iloc[(df.frame_timestamp - t).abs().argsort()[:1]]


def dentro_de_pista(df, columna, minimo, maximo):
    serie = df[columna].dropna()
    if serie.empty:
        return True
    return bool(serie.min() >= minimo - 1e-6 and serie.max() <= maximo + 1e-6)


def case_silencio_largo_sin_pitch(df):
    zona = df[(df.frame_timestamp > 1.3) & (df.frame_timestamp < 4.7)]
    inventados = int(zona.pitch.notna().sum())
    print(f"[{'ok ' if inventados == 0 else 'FAIL'}] silencio de 4 s -> "
          f"{inventados} de {len(zona)} fotogramas con pitch numérico"
          + ("" if inventados == 0 else f" (mediana {zona.pitch.median():.1f} Hz de la spline)"))
    return inventados == 0


def case_fuera_de_pista_todo_null(df):
    fuera = df[df.frame_timestamp > PITCH_FIN]
    columnas = ["pitch", "intensity", "harmonicity", "formant.1_frequency"]
    sucias = {c: int(fuera[c].notna().sum()) for c in columnas if c in fuera}
    total = sum(sucias.values())
    print(f"[{'ok ' if total == 0 else 'FAIL'}] despues del fin de las pistas "
          f"({PITCH_FIN} s, {len(fuera)} fotogramas) -> {total} valores inventados "
          f"{ {k: v for k, v in sucias.items() if v} if total else ''}")
    return total == 0


def case_nada_fuera_del_rango_de_su_pista(df):
    fallos = []
    if not dentro_de_pista(df, "pitch", PITCH_MIN, PITCH_MAX):
        fallos.append(f"pitch {df.pitch.min():.1f}..{df.pitch.max():.1f} (pista {PITCH_MIN}..{PITCH_MAX})")
    if not dentro_de_pista(df, "formant.1_frequency", 500.0, 500.0):
        fallos.append(f"F1 {df['formant.1_frequency'].min():.0f}..{df['formant.1_frequency'].max():.0f} (pista 500)")
    if not dentro_de_pista(df, "harmonicity", SUELO_HARM, 20.0):
        fallos.append(f"harmonicity {df.harmonicity.min():.1f} (suelo de Praat {SUELO_HARM})")
    print(f"[{'ok ' if not fallos else 'FAIL'}] todo valor cae dentro del rango de su pista"
          + ("" if not fallos else "  ->  " + "; ".join(fallos)))
    return not fallos


def case_cero_de_praat_no_es_un_valor(df):
    ceros = int((df.pitch == 0).sum())
    print(f"[{'ok ' if ceros == 0 else 'FAIL'}] el 0 de Praat (candidato mute) no se publica"
          f" -> {ceros} fotogramas con pitch == 0")
    return ceros == 0


def case_agujero_corto_si_tiene_valor(df):
    fila = en((AGUJERO_INCIO + AGUJERO_FIN) / 2, df)
    valor = float(fila.pitch.iloc[0]) if pd.notna(fila.pitch.iloc[0]) else None
    ok = valor is not None and PITCH_MIN <= valor <= PITCH_MAX
    print(f"[{'ok ' if ok else 'FAIL'}] hueco de {(AGUJERO_FIN-AGUJERO_INCIO)*1000:.0f} ms dentro de una "
          f"frase queda puenteado con un pitch real"
          + (f" -> {valor:.1f} Hz" if valor is not None else " -> NULL (demasiado null: se pierde la frase)"))
    return ok


def case_una_fila_por_fotograma(df, n_frames):
    ok = len(df) == n_frames and list(df.frame_id) == list(range(n_frames))
    print(f"[{'ok ' if ok else 'FAIL'}] una fila por fotograma (contrato con quien consume el Parquet) -> "
          f"{len(df)} filas / {n_frames} fotogramas")
    return ok


def case_voice_present_coherente(df):
    if "voice_present" not in df.columns:
        print("[FAIL] falta la columna voice_present -> no se puede saber donde hay voz medida")
        return False
    coincide = bool(((df.pitch.notna()) == df.voice_present.fillna(False)).all())
    print(f"[{'ok ' if coincide else 'FAIL'}] voice_present == donde hay pitch medido "
          f"({int(df.voice_present.fillna(False).sum())} de {len(df)} fotogramas)")
    return coincide


def case_intensity_no_se_null_ea_de_mas(df):
    dentro = df[(df.frame_timestamp > 0.10) & (df.frame_timestamp < INT_FIN - 0.05)]
    nulls = int(dentro.intensity.isna().sum())
    ok = nulls == 0
    print(f"[{'ok ' if ok else 'FAIL'}] la intensidad medida por Praat se conserva "
          f"aún en silencio -> {nulls} NULL de {len(dentro)} fotogramas con pista")
    return ok


if __name__ == "__main__":
    if not (os.path.isfile(RSCRIPT) and os.path.isfile(ALINEADOR)):
        # Sin el codigo no hay nada que probar: esto no es un fallo. Con el codigo OLD (sin
        # prosody_align.R) si que deberia saltar, que es para lo que existe este test.
        print("[skip] no estan los scripts que prueba este test:")
        print(f"       {RSCRIPT}")
        print(f"       {ALINEADOR}")
        print("\nTOTAL: 0/0")
        sys.exit(0)
    with tempfile.TemporaryDirectory() as tmp:
        n_frames = escribir_entrada(tmp)
        escribir_pitch(tmp)
        escribir_matriz(tmp, "intensity", ".Intensity", 0.043, INT_FIN, 0.005,
                        lambda t: 50.0 + 20.0 * (1 if t < 3 else 0.5))
        escribir_matriz(tmp, "harmonicity", ".Harmonicity", 0.014, HARM_FIN, 0.010,
                        lambda t: SUELO_HARM if SIL_INCIO <= t <= SIL_FIN else 15.0)
        escribir_formantes(tmp)
        try:
            df = ejecutar(tmp)
        except Exception as e:  # noqa: BLE001
            print(f"[FAIL] no se pudo ejecutar la cadena de prosodia: {e}")
            print("\nTOTAL: 0/8")
            sys.exit(1)
        resultados = [
            case_silencio_largo_sin_pitch(df),
            case_fuera_de_pista_todo_null(df),
            case_nada_fuera_del_rango_de_su_pista(df),
            case_cero_de_praat_no_es_un_valor(df),
            case_agujero_corto_si_tiene_valor(df),
            case_una_fila_por_fotograma(df, n_frames),
            case_voice_present_coherente(df),
            case_intensity_no_se_null_ea_de_mas(df),
        ]
    print("\nTOTAL:", sum(resultados), "/", len(resultados))
    sys.exit(0 if all(resultados) else 1)
