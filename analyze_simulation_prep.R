suppressPackageStartupMessages({
  source("utils_logging.R", local = TRUE)
})

default_manifest_path <- function() {
  file.path(getwd(), "data", "simulation_manifest.csv")
}

default_session_summary_path <- function() {
  file.path(getwd(), "data", "session_summary.csv")
}

ensure_simulation_manifest <- function(manifest_path = default_manifest_path()) {
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
      stringsAsFactors = FALSE
    )
    utils::write.csv(header, manifest_path, row.names = FALSE)
  }

  invisible(manifest_path)
}

reset_simulation_manifest <- function(manifest_path = default_manifest_path()) {
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
      stringsAsFactors = FALSE
    ),
    manifest_path,
    row.names = FALSE
  )

  invisible(manifest_path)
}

ensure_session_summary <- function(summary_path = default_session_summary_path()) {
  summary_dir <- dirname(summary_path)
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
  }

  if (!file.exists(summary_path)) {
    header <- data.frame(
      session_id = character(),
      variant = character(),
      persona = character(),
      run_label = character(),
      first_key_action_taken = logical(),
      task_completed = logical(),
      session_duration = numeric(),
      num_events = integer(),
      stringsAsFactors = FALSE
    )
    utils::write.csv(header, summary_path, row.names = FALSE)
  }

  invisible(summary_path)
}

reset_session_summary <- function(summary_path = default_session_summary_path()) {
  summary_dir <- dirname(summary_path)
  if (!dir.exists(summary_dir)) {
    dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)
  }

  utils::write.csv(
    data.frame(
      session_id = character(),
      variant = character(),
      persona = character(),
      run_label = character(),
      first_key_action_taken = logical(),
      task_completed = logical(),
      session_duration = numeric(),
      num_events = integer(),
      stringsAsFactors = FALSE
    ),
    summary_path,
    row.names = FALSE
  )

  invisible(summary_path)
}

extract_duration_seconds <- function(event_values) {
  if (!length(event_values)) {
    return(NA_real_)
  }

  duration_value <- sub("^duration_seconds=", "", event_values[1])
  suppressWarnings(as.numeric(duration_value))
}

build_session_summary <- function(
  log_path = default_event_log_path(),
  manifest_path = default_manifest_path(),
  summary_path = default_session_summary_path()
) {
  ensure_event_log_file(log_path)
  ensure_simulation_manifest(manifest_path)
  ensure_session_summary(summary_path)

  event_log <- utils::read.csv(log_path, stringsAsFactors = FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)

  if (!"run_label" %in% names(event_log)) {
    event_log$run_label <- ""
  }

  if (!nrow(manifest)) {
    utils::write.csv(
      data.frame(
        session_id = character(),
        variant = character(),
        persona = character(),
        run_label = character(),
        first_key_action_taken = logical(),
        task_completed = logical(),
        session_duration = numeric(),
        num_events = integer(),
        stringsAsFactors = FALSE
      ),
      summary_path,
      row.names = FALSE
    )
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
      first_key_action_taken = any(session_rows$event_name == "first_key_action"),
      task_completed = any(session_rows$event_name == "task_completed"),
      session_duration = extract_duration_seconds(session_rows$event_value[session_rows$event_name == "session_end"]),
      num_events = nrow(session_rows),
      stringsAsFactors = FALSE
    )
  })

  summary_df <- do.call(rbind, summary_rows)
  utils::write.csv(summary_df, summary_path, row.names = FALSE)
  invisible(summary_df)
}

if (sys.nframe() == 0) {
  summary_df <- build_session_summary()
  cat("session_summary_rows=", nrow(summary_df), "\n", sep = "")
}
