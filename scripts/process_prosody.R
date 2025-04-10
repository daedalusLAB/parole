#!/usr/bin/env Rscript

# PAROLE: Script para procesado prosódico de voz
# Copyright (C) 2025  Brian Herreño Jiménez & Cristóbal Pagán Cánovas
#
# Distribuido bajo los términos de la GNU General Public License v3 o superior.
# Ver el archivo LICENSE en el repositorio para más información.

# -------------------------------------------------------------
# Asegurar que 'arrow' esté instalado, única dependencia externa
# -------------------------------------------------------------
if (!requireNamespace("arrow", quietly = TRUE)) {
  stop("El paquete 'arrow' es necesario para escribir archivos Parquet. Instálalo con install.packages('arrow')")
}

# -------------------------------------------------------------
# Cargar 'parallel' de la base de R (no requiere instalación extra)
# -------------------------------------------------------------
suppressWarnings(suppressMessages({
  library(parallel)
}))

#######################################################################
# process_prosody.R
#
# Uso:
#   Rscript process_prosody.R <video_dir> <out_file>
#
# Donde:
#   - <video_dir>: carpeta con:
#       - Archivos .Pitch, .Formant, etc. de Praat
#       - CSV de timestamps (_frame_timestamps.csv)
#       - (Opcional) CSV de Silero (_silero_segments.csv)
#   - <out_file>: Nombre del archivo de salida (p.ej. .csv o .parquet)
#
#######################################################################

# --- 0. Parseo de argumentos ---
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Uso: Rscript process_prosody.R <video_dir> <out_file>", call. = FALSE)
}
video_dir <- args[1]
out_file  <- args[2]

# Número máximo de formantes (ajusta a tu gusto)
max_formants <- 5

#######################################################################
# 1. Sub-funciones de parseo: Pitch, Intensity, Formant, etc.
#######################################################################
parse_praat_pitch <- function(files) {
  # Si no hay archivos .Pitch, devolvemos NULL
  if (length(files) == 0) return(NULL)
  
  parse_one_pitch <- function(file) {
    lines <- readLines(file)
    
    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))
    
    data_list <- list()
    frame_lines <- grep("^    frames \\[", lines)
    
    for (i in seq_along(frame_lines)) {
      line_i <- frame_lines[i]
      time   <- x1 + (i - 1) * dx
      
      # "intensity_pitch" es la intensidad asociada al frame de pitch
      intensity_pitch <- as.numeric(gsub(".*= ", "", lines[line_i + 1]))
      n_candidates    <- as.numeric(gsub(".*= ", "", lines[line_i + 2]))
      
      if (n_candidates < 1) {
        data_list[[i]] <- data.frame(
          time = time,
          intensity_pitch = intensity_pitch,
          pitch = NA,
          strength_pitch = NA
        )
        next
      }
      
      frame_block <- lines[
        (line_i + 3) : (ifelse(i < length(frame_lines),
                               frame_lines[i + 1] - 1, length(lines)))
      ]
      
      # Tomar solo el primer candidato [1]
      cand1_idx <- grep("^\\s+candidates \\[1\\]:", frame_block)
      if (length(cand1_idx) == 0) {
        pitch_val <- NA
        strength_pitch <- NA
      } else {
        freq_line <- frame_block[cand1_idx + 1]
        strg_line <- frame_block[cand1_idx + 2]
        pitch_val <- as.numeric(gsub(".*= ", "", freq_line))
        strength_pitch <- as.numeric(gsub(".*= ", "", strg_line))
      }
      
      data_list[[i]] <- data.frame(
        time = time,
        intensity_pitch = intensity_pitch,
        pitch = pitch_val,
        strength_pitch = strength_pitch
      )
    }
    do.call(rbind, data_list)
  }
  
  # Procesamos secuencialmente, un solo hilo
  df_list <- lapply(files, parse_one_pitch)
  do.call(rbind, df_list)
}

parse_praat_intensity <- function(files) {
  if (length(files) == 0) return(NULL)
  
  parse_one_intensity <- function(file) {
    lines <- readLines(file)
    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))
    
    z_start <- grep("z \\[\\]\\ \\[\\]:", lines)
    z_lines <- lines[(z_start + 2) : length(lines)]
    z_vals  <- as.numeric(gsub(".*= ", "", z_lines))
    
    times <- seq(from = x1, by = dx, length.out = length(z_vals))
    data.frame(time = times, intensity = z_vals)
  }
  
  df_list <- lapply(files, parse_one_intensity)
  do.call(rbind, df_list)
}

parse_praat_harmonicity <- function(files) {
  if (length(files) == 0) return(NULL)
  
  parse_one_harmo <- function(file) {
    lines <- readLines(file)
    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))
    
    z_start <- grep("z \\[\\]\\ \\[\\]:", lines)
    z_lines <- lines[(z_start + 2):length(lines)]
    z_vals  <- as.numeric(gsub(".*= ", "", z_lines))
    
    times <- seq(from = x1, by = dx, length.out = length(z_vals))
    data.frame(time = times, harmonicity = z_vals)
  }
  
  df_list <- lapply(files, parse_one_harmo)
  do.call(rbind, df_list)
}

parse_praat_formant <- function(files, max_formants = 5) {
  if (length(files) == 0) return(NULL)
  
  parse_one_formant <- function(file) {
    lines <- readLines(file)
    x1  <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx  <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))
    
    frame_lines <- grep("^\\s+frames \\[", lines)
    data_list <- vector("list", length(frame_lines))
    
    for (i in seq_along(frame_lines)) {
      time <- x1 + (i - 1) * dx
      start <- frame_lines[i]
      end   <- if (i < length(frame_lines)) frame_lines[i + 1] - 1 else length(lines)
      frame_block <- lines[start:end]
      
      intensity_line <- grep("^\\s+intensity = ", frame_block, value = TRUE)
      intensity_val  <- if (length(intensity_line) > 0) as.numeric(gsub(".*= ", "", intensity_line)) else NA
      
      row <- list(time = time, intensity = intensity_val)
      
      # Extraer F1..Fmax
      for (f in seq_len(max_formants)) {
        f_block <- grep(sprintf("^\\s+formant \\[%d\\]:", f), frame_block)
        if (length(f_block) == 0) {
          row[[paste0("formant.", f, "_frequency")]] <- NA
          row[[paste0("formant.", f, "_bandwidth")]] <- NA
        } else {
          freq_line <- frame_block[f_block + 1]
          bw_line   <- frame_block[f_block + 2]
          row[[paste0("formant.", f, "_frequency")]] <- as.numeric(gsub(".*= ", "", freq_line))
          row[[paste0("formant.", f, "_bandwidth")]] <- as.numeric(gsub(".*= ", "", bw_line))
        }
      }
      data_list[[i]] <- as.data.frame(row)
    }
    do.call(rbind, data_list)
  }
  
  df_list <- lapply(files, parse_one_formant)
  do.call(rbind, df_list)
}

parse_praat_pointprocess <- function(files) {
  if (length(files) == 0) return(NULL)
  
  parse_one_pp <- function(file) {
    lines <- readLines(file)
    t_start <- grep("^t \\[\\]:", lines)
    t_lines <- lines[(t_start + 1):length(lines)]
    
    t_vals <- as.numeric(gsub(".*= ", "", t_lines))
    data.frame(time = t_vals)
  }
  
  df_list <- lapply(files, parse_one_pp)
  do.call(rbind, df_list)
}

#######################################################################
# 2. Hacer cada parse (pitch, intensity, etc.) en paralelo, un núcleo cada uno
#######################################################################
parse_all_tasks_in_parallel <- function(dir, max_formants = 5) {
  # Armar lista de archivos
  pitch_files        <- list.files(dir, pattern = "\\.Pitch$",        full.names = TRUE)
  intensity_files    <- list.files(dir, pattern = "\\.Intensity$",    full.names = TRUE)
  harmonicity_files  <- list.files(dir, pattern = "\\.Harmonicity$",  full.names = TRUE)
  formant_files      <- list.files(dir, pattern = "\\.Formant(s)?$",  full.names = TRUE)
  pointprocess_files <- list.files(dir, pattern = "\\.PointProcess$", full.names = TRUE)
  
  # Definir tareas: cada una se ejecuta con un solo hilo, pero en paralelo entre sí
  tasks <- list(
    pitch = function() parse_praat_pitch(pitch_files),
    intensity = function() parse_praat_intensity(intensity_files),
    harmonicity = function() parse_praat_harmonicity(harmonicity_files),
    formant = function() parse_praat_formant(formant_files, max_formants),
    pointprocess = function() parse_praat_pointprocess(pointprocess_files)
  )
  
  # Filtrar tareas que realmente tengan archivos (para no lanzar en paralelo algo vacío)
  tasks_filtered <- tasks[
    sapply(tasks, function(fun) {
      # Chequeamos si hay archivos en la función
      # heurística: si la función parse pitch no hay, ni se llama. 
      # Pero para simplicidad, ejecutamos la función en un test:
      # Prefiero no ejecutar la parse, así que mejor revisamos tamaño de file vector:
      # Realmente, para no complicar, revisamos con un mini truco:
      # "pitch_files" etc. ya las tenemos. 
      # Lo haré de forma más limpia:
      TRUE
    })
  ]
  
  # Para no complicar, lanzamos las 5 de todos modos, 
  # cada una devolviendo NULL si no hay archivos.
  # Podríamos filtrar, pero no es imprescindible.
  
  # `length(tasks_filtered)` = 5 en general
  # Corremos cada tarea en un proceso diferente (mc.cores = length(tasks_filtered))
  # Cada tarea se ejecuta con lapply interno → un hilo
  results <- mclapply(tasks, function(f) f(), mc.cores = length(tasks))
  
  # Devuelve un named list con pitch, intensity, ...
  names(results) <- names(tasks)
  results
}

#######################################################################
# 3. Cargar timestamps, Silero, y hacer spline
#######################################################################

# Localizar CSV de timestamps
timestamps_csv <- list.files(video_dir, pattern = "_frame_timestamps\\.csv$", full.names = TRUE)
if (length(timestamps_csv) == 0) {
  stop("❌ No se encontró '_frame_timestamps.csv' en ", video_dir)
} else if (length(timestamps_csv) > 1) {
  warning("⚠️ Se encontró más de un CSV de timestamps. Usando el primero:\n", timestamps_csv[1])
}
timestamps_csv <- timestamps_csv[1]

df_timestamps <- read.csv(timestamps_csv)
df_timestamps <- df_timestamps[-1, ]
df_timestamps$frame_timestamp[1] <- 0
row.names(df_timestamps) <- NULL

# Llamar a la función que parsea TODO en paralelo, un núcleo por tarea
prosody_data <- parse_all_tasks_in_parallel(video_dir, max_formants)

# CSV de Silero
silero_csv_path <- list.files(video_dir, pattern = "_silero_segments\\.csv$", full.names = TRUE)
df_silero <- if (length(silero_csv_path) == 1) {
  read.csv(silero_csv_path, stringsAsFactors = FALSE)
} else {
  if (length(silero_csv_path) > 1) {
    warning("⚠️ Hay más de un archivo '_silero_segments.csv'. Usando el primero.")
  } else {
    warning("❌ Silero VAD no encontrado. Se omite.")
  }
  NULL
}

# Función de spline
interpolate_spline <- function(time, values, new_times, method = "fmm") {
  valid <- !is.na(values) & !is.na(time)
  if (sum(valid) < 4) {
    return(rep(NA, length(new_times)))
  }
  f_spline <- splinefun(time[valid], values[valid], method = method)
  f_spline(new_times)
}

#######################################################################
# 4. Interpolar en df_final
#######################################################################
frame_times <- df_timestamps$frame_timestamp
df_final    <- df_timestamps

# 4a. Pitch
if (!is.null(prosody_data$pitch)) {
  df_final$pitch <- interpolate_spline(
    prosody_data$pitch$time,
    prosody_data$pitch$pitch,
    frame_times
  )
  df_final$pitch[df_final$pitch < 10] <- 0
} else {
  df_final$pitch <- NA
}

# 4b. Intensity
if (!is.null(prosody_data$intensity)) {
  df_final$intensity <- interpolate_spline(
    prosody_data$intensity$time,
    prosody_data$intensity$intensity,
    frame_times
  )
} else {
  df_final$intensity <- NA
}

# 4c. Harmonicity
if (!is.null(prosody_data$harmonicity)) {
  df_final$harmonicity <- interpolate_spline(
    prosody_data$harmonicity$time,
    prosody_data$harmonicity$harmonicity,
    frame_times
  )
} else {
  df_final$harmonicity <- NA
}

# 4d. Formants F1..F5
if (!is.null(prosody_data$formant)) {
  for (i in seq_len(max_formants)) {
    freq_col <- paste0("formant.", i, "_frequency")
    if (freq_col %in% names(prosody_data$formant)) {
      df_final[[freq_col]] <- interpolate_spline(
        prosody_data$formant$time,
        prosody_data$formant[[freq_col]],
        frame_times
      )
    } else {
      df_final[[freq_col]] <- NA
    }
  }
}

# 4e. VAD
if (!is.null(df_silero)) {
  df_final$vad <- sapply(df_final$frame_timestamp, function(t) {
    any(t >= df_silero$start & t <= df_silero$end)
  })
} else {
  df_final$vad <- NA
}

#######################################################################
# 5. Guardar en CSV o Parquet
#######################################################################
out_path <- file.path(video_dir, out_file)

if (grepl("\\.parquet$", tolower(out_file))) {
  arrow::write_parquet(df_final, out_path)
  message("✅ Proceso completado. Archivo Parquet guardado en: ", out_path)
} else if (grepl("\\.csv$", tolower(out_file))) {
  write.csv(df_final, out_path, row.names = FALSE)
  message("✅ Proceso completado. CSV final guardado en: ", out_path)
} else {
  warning("⚠️ Extensión de archivo no reconocida. Se guarda como CSV por defecto.")
  write.csv(df_final, out_path, row.names = FALSE)
  message("✅ Proceso completado. Archivo guardado como CSV en: ", out_path)
}

