suppressPackageStartupMessages({
  source("utils_logging.R", local = TRUE)
})

ensure_simulation_manifest <- function(manifest_path = default_manifest_path()) {
  manifest_path <- manifest_path %||% default_simulation_manifest_path()
  manifest_dir <- dirname(manifest_path)
  if (!dir.exists(manifest_dir)) {
    dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  }

  if (!file.exists(manifest_path)) {
    header <- data.frame(
      session_id = character(),
      variant = character(),
      persona = character(),
      run_label = character(),
      planned_dataset = character(),
      data_source = character(),
      stringsAsFactors = FALSE
    )
    utils::write.csv(header, manifest_path, row.names = FALSE)
  } else {
    existing <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
    template <- data.frame(
      session_id = character(),
      variant = character(),
      persona = character(),
      run_label = character(),
      planned_dataset = character(),
      data_source = character(),
      stringsAsFactors = FALSE
    )
    if (nrow(existing)) {
      missing_cols <- setdiff(names(template), names(existing))
      for (col_name in missing_cols) {
        existing[[col_name]] <- rep("", nrow(existing))
      }
      existing <- existing[, names(template), drop = FALSE]
      blank_sources <- is.na(existing$data_source) | !nzchar(existing$data_source)
      existing$data_source[blank_sources] <- "simulated"
    } else {
      existing <- template[0, , drop = FALSE]
    }
    utils::write.csv(existing, manifest_path, row.names = FALSE)
  }

  invisible(manifest_path)
}

reset_simulation_manifest <- function(manifest_path = default_manifest_path()) {
  manifest_path <- manifest_path %||% default_simulation_manifest_path()
  manifest_dir <- dirname(manifest_path)
  if (!dir.exists(manifest_dir)) {
    dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  }

  utils::write.csv(
    data.frame(
      session_id = character(),
      variant = character(),
      persona = character(),
      run_label = character(),
      planned_dataset = character(),
      data_source = character(),
      stringsAsFactors = FALSE
    ),
    manifest_path,
    row.names = FALSE
  )

  invisible(manifest_path)
}

default_manifest_path <- function() {
  default_simulation_manifest_path()
}

default_simulated_summary_path <- function() {
  default_session_summary_path("simulated")
}

extract_duration_seconds <- function(event_values) {
  if (!length(event_values)) {
    return(NA_real_)
  }

  duration_value <- sub("^duration_seconds=", "", event_values[1])
  suppressWarnings(as.numeric(duration_value))
}

build_session_summary <- function(
  log_path = default_event_log_path("simulated"),
  manifest_path = default_manifest_path(),
  summary_path = default_simulated_summary_path()
) {
  ensure_legacy_simulated_data_migrated()
  ensure_event_log_file(log_path)
  ensure_simulation_manifest(manifest_path)
  ensure_session_summary_file(summary_path)

  event_log <- utils::read.csv(log_path, stringsAsFactors = FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)

  if (!"run_label" %in% names(event_log)) {
    event_log$run_label <- ""
  }
  if (!"data_source" %in% names(event_log)) {
    event_log$data_source <- "simulated"
  }
  if (!"data_source" %in% names(manifest)) {
    manifest$data_source <- "simulated"
  }

  if (!nrow(manifest)) {
    utils::write.csv(session_summary_header(), summary_path, row.names = FALSE)
    return(invisible(data.frame()))
  }

  summary_rows <- lapply(seq_len(nrow(manifest)), function(i) {
    manifest_row <- manifest[i, , drop = FALSE]
    session_rows <- event_log[
      event_log$session_id == manifest_row$session_id &
        event_log$run_label == manifest_row$run_label,
      ,
      drop = FALSE
    ]

    data.frame(
      session_id = manifest_row$session_id,
      variant = manifest_row$variant,
      persona = manifest_row$persona,
      run_label = manifest_row$run_label,
      data_source = "simulated",
      first_key_action_taken = any(session_rows$event_name == "first_key_action"),
      task_completed = any(session_rows$event_name == "task_completed"),
      session_duration = extract_duration_seconds(session_rows$event_value[session_rows$event_name == "session_end"]),
      num_events = nrow(session_rows),
      stringsAsFactors = FALSE
    )
  })

  summary_df <- normalize_session_summary_frame(do.call(rbind, summary_rows), default_source = "simulated")
  utils::write.csv(summary_df, summary_path, row.names = FALSE)
  invisible(summary_df)
}

if (sys.nframe() == 0) {
  summary_df <- build_session_summary()
  cat("session_summary_rows=", nrow(summary_df), "\n", sep = "")
}
