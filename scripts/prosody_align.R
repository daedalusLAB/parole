# prosody_align.R — aterrizaje de las pistas de Praat en la rejilla de fotogramas.
#
# POR QUÉ EXISTE ESTE FICHERO
# ---------------------------
# Praat entrega pistas a 1-10 ms y el video tiene fotogramas a ~33 ms. Alguien tiene
# que decidir qué valor lleva cada fotograma, y la decisión no puede ser "ajustar una
# curva a todo y evaluar donde haga falta": eso convierte la medida en un modelo de la
# medida. Este módulo solo interpola donde hay medida, y dice NULL en el resto.
#
# LO QUE HACÍA ANTES `process_prosody.R` (y por qué estaba mal)
# ------------------------------------------------------------
# `interpolate_spline()` tiraba los NA antes de ajustar (`valid <- !is.na(values)`),
# construía UNA spline cúbica con todos los puntos restantes y la evaluaba en TODOS los
# fotogramas. Tres consecuencias, todas medidas sobre las entregas:
#
#   1. Rellenaba silencios de cualquier duración. Con cuatro puntos válidos en todo el
#      clip, el 100 % de los fotogramas salía con número. En un clip real de 5,2 s,
#      1715 de 5129 frames de pitch son silencio (el candidato "mute" de Praat, que se
#      escribe como `frequency = 0`): en la entrega eran fotogramas con pitch.
#   2. Extrapola fuera del rango pistado y no se puede apagar: `splinefun` no admite el
#      argumento `extrapolation` (probado: `unused argument`). En los datos entregados
#      quedó una F5 de -658.034 Hz y otra de 29.144.321 Hz, cuando `To Formant (burg)`
#      está configurado con techo 5500 Hz; y un HNR de -246,7 dB, cuando el suelo del
#      Harmonicity (cc) de Praat es -200 dB.
#   3. `df_final$pitch[df_final$pitch < 10] <- 0` pintaba de 0 el resultado de (2). Un 0
#      en una magnitud física es indistinguible de una medida: en una entrega, 1408 de
#      4553 fotogramas (30,9 %) decían `pitch == 0` y la media de pitch salía 125,3 Hz en
#      vez de 182,5 Hz.
#
# QUÉ HACE AHORA
# --------------
# `align_track()` parte cada pista en TRAMOS de muestras consecutivas (un hueco mayor
# que MAX_GAP_S rompe el tramo) y, dentro de cada tramo, interpola LINEAL. Fuera de un
# tramo: NULL. Con un paso de pista de 1-10 ms frente a fotogramas de ~33 ms, la
# interpolación lineal es una lectura casi directa de la pista, y tiene una propiedad que
# la cúbica no: ningún valor sale fuera del rango de lo medido en ese tramo.
#
# LAS CONSTANTES VAN AQUÍ, DECLARADAS, NO EMPOTRADAS EN EL CÓDIGO
# ---------------------------------------------------------------
# MAX_GAP_S = 0,1 s: medido en un clip real de noticiario, las rachas de silencio del
#   pitch tienen mediana 70 ms, p90 238 ms y máximo 359 ms; los huecos de <= 100 ms son
#   los que caen dentro de una misma frase (oclusivas, microdesasordamientos). 0,1 s
#   equivale a ~3 fotogramas a 30 fps: se puentea lo que sigue siendo la misma emisión y
#   se deja NULL donde hay silencio de verdad.

# Hueco máximo, en segundos, que se sigue considerando "la misma pista".
MAX_GAP_S <- 0.1

# Muestras mínimas para que un tramo produzca valores: con una sola marca de tiempo no
# hay nada que interpolar, y publicar el valor de esa muestra en varios fotogramas sería
# inventar cobertura.
MIN_TRACK_POINTS <- 2

# Alinea una pista de Praat (time, values) en la rejilla de fotogramas `new_times`.
#
#   time, values : vectores de la pista, en el orden en que los escupió Praat.
#   new_times    : marcas de tiempo de los fotogramas.
#   max_gap_s    : hueco por encima del cual se rompe el tramo (NULL en el hueco).
#
# Devuelve un vector numérico de la misma longitud que `new_times`, con NULL fuera de
# todo tramo. Nunca extrapola y nunca saca un valor del rango observado en el tramo.
align_track <- function(time, values, new_times, max_gap_s = MAX_GAP_S) {
  salida <- rep(NA_real_, length(new_times))
  validos <- which(!is.na(time) & !is.na(values))
  if (length(validos) == 0) return(salida)

  t_ <- time[validos]
  v_ <- values[validos]
  orden <- order(t_)
  t_ <- t_[orden]
  v_ <- v_[orden]
  # Marcas de tiempo repetidas (dos ficheros de Praat que solapan, o redondeo): una sola,
  # si no, `approx` se queja de x no estrictamente creciente.
  unicos <- !duplicated(t_)
  t_ <- t_[unicos]
  v_ <- v_[unicos]
  if (length(t_) < MIN_TRACK_POINTS) return(salida)

  tramo <- cumsum(c(TRUE, diff(t_) > max_gap_s))
  for (k in unique(tramo)) {
    idx <- which(tramo == k)
    if (length(idx) < MIN_TRACK_POINTS) next
    dentro <- new_times >= t_[idx[1]] & new_times <= t_[idx[length(idx)]]
    if (!any(dentro)) next
    # `rule` se deja deliberadamente en su valor por defecto (NA): si un fotograma se
    # colara fuera del tramo, tiene que salir NULL, no una copia del extremo.
    salida[dentro] <- approx(t_[idx], v_[idx], xout = new_times[dentro],
                             method = "linear")$y
  }
  salida
}

# El pitch de Praat marca el silencio como candidato "mute": nCandidates sigue valiendo 1
# y `frequency = 0`. Un 0 no es una frecuencia: es la ausencia de pista voiced, y tiene
# que llegar al alineador como hueco (NULL), no como un valor que se puede promediar.
marcar_silencio_pitch <- function(frecuencias) {
  fuera <- !is.na(frecuencias) & frecuencias <= 0
  frecuencias[fuera] <- NA_real_
  frecuencias
}
