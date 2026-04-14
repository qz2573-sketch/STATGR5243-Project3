suppressPackageStartupMessages({
  source("utils_logging.R", local = TRUE)
})

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

parse_prepare_args <- function(args) {
  config <- list(
    input_path = file.path("data", "real", "ga4_events_export.csv"),
    output_path = file.path("data", "real", "session_summary_real_ga4.csv")
  )

  for (arg in args) {
    if (grepl("^--input=", arg)) {
      config$input_path <- sub("^--input=", "", arg)
    } else if (grepl("^--output=", arg)) {
      config$output_path <- sub("^--output=", "", arg)
    }
  }

  config
}

first_matching_col <- function(df, candidates) {
  matches <- candidates[candidates %in% names(df)]
  if (!length(matches)) {
    return(NULL)
  }
  matches[[1]]
}

extract_col <- function(df, candidates, default = NA_character_) {
  col_name <- first_matching_col(df, candidates)
  if (is.null(col_name)) {
    return(rep(default, nrow(df)))
  }
  as.character(df[[col_name]])
}

coerce_logical_flag <- function(x) {
  normalized <- tolower(trimws(as.character(x)))
  normalized %in% c("true", "1", "yes")
}

coerce_numeric_value <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

last_non_empty <- function(x, default = NA_character_) {
  values <- as.character(x)
  values <- values[!is.na(values) & nzchar(trimws(values)) & values != "NA"]
  if (!length(values)) {
    return(default)
  }
  values[[length(values)]]
}

normalize_ga_export <- function(df) {
  event_name_raw <- extract_col(df, c("event_name", "Event name", "eventName", "eventName.x"))
  event_name <- vapply(event_name_raw, normalize_ga_event_name, character(1))
  session_id <- extract_col(df, c(
    "session_id", "Event parameter: session_id", "Custom parameter: session_id",
    "customEvent:session_id", "Session ID"
  ))
  variant <- extract_col(df, c(
    "variant", "Event parameter: variant", "Custom parameter: variant",
    "customEvent:variant", "User property: variant"
  ))
  persona <- extract_col(df, c(
    "persona", "Event parameter: persona", "Custom parameter: persona",
    "customEvent:persona"
  ))
  run_label <- extract_col(df, c(
    "run_label", "Event parameter: run_label", "Custom parameter: run_label",
    "customEvent:run_label", "User property: run_label"
  ))
  data_source <- extract_col(df, c(
    "data_source", "Event parameter: data_source", "Custom parameter: data_source",
    "customEvent:data_source", "User property: data_source"
  ), default = "real_user")
  session_duration <- coerce_numeric_value(extract_col(df, c(
    "session_duration", "Event parameter: session_duration",
    "Custom parameter: session_duration", "customEvent:session_duration",
    "session_duration_seconds", "Event parameter: session_duration_seconds",
    "Custom parameter: session_duration_seconds", "customEvent:session_duration_seconds"
  )))
  num_events <- coerce_numeric_value(extract_col(df, c(
    "num_events", "Event parameter: num_events",
    "Custom parameter: num_events", "customEvent:num_events",
    "event_count", "Event parameter: event_count",
    "Custom parameter: event_count", "customEvent:event_count"
  )))
  first_key_param <- coerce_logical_flag(extract_col(df, c(
    "first_key_action_taken", "Event parameter: first_key_action_taken",
    "Custom parameter: first_key_action_taken", "customEvent:first_key_action_taken"
  ), default = "FALSE"))
  task_completed_param <- coerce_logical_flag(extract_col(df, c(
    "task_completed", "Event parameter: task_completed",
    "Custom parameter: task_completed", "customEvent:task_completed"
  ), default = "FALSE"))

  event_df <- data.frame(
    session_id = session_id,
    event_name = event_name,
    variant = variant,
    persona = persona,
    run_label = run_label,
    data_source = data_source,
    session_duration = session_duration,
    num_events = num_events,
    first_key_action_taken = first_key_param | event_name == "first_key_action",
    task_completed = task_completed_param | event_name == "task_completed",
    stringsAsFactors = FALSE
  )

  event_df <- event_df[!is.na(event_df$session_id) & nzchar(trimws(event_df$session_id)), , drop = FALSE]
  if (!nrow(event_df)) {
    stop("No session_id values were found in the GA4 export.")
  }

  session_rows <- lapply(split(event_df, event_df$session_id), function(session_df) {
    duration_candidates <- session_df$session_duration[is.finite(session_df$session_duration)]
    num_event_candidates <- session_df$num_events[is.finite(session_df$num_events)]

    data.frame(
      session_id = session_df$session_id[[1]],
      variant = toupper(last_non_empty(session_df$variant, default = "")),
      persona = last_non_empty(session_df$persona, default = NA_character_),
      run_label = last_non_empty(session_df$run_label, default = ""),
      data_source = last_non_empty(session_df$data_source, default = "real_user"),
      first_key_action_taken = any(session_df$first_key_action_taken, na.rm = TRUE),
      task_completed = any(session_df$task_completed, na.rm = TRUE),
      session_duration = if (length(duration_candidates)) max(duration_candidates, na.rm = TRUE) else NA_real_,
      num_events = as.integer(if (length(num_event_candidates)) max(num_event_candidates, na.rm = TRUE) else nrow(session_df)),
      stringsAsFactors = FALSE
    )
  })

  prepared <- do.call(rbind, session_rows)
  prepared$persona[!nzchar(prepared$persona) | prepared$persona == "NA"] <- NA_character_
  prepared$data_source[!nzchar(prepared$data_source)] <- "real_user"
  prepared
}

if (sys.nframe() == 0) {
  config <- parse_prepare_args(commandArgs(trailingOnly = TRUE))

  if (!file.exists(config$input_path)) {
    stop(sprintf("GA4 export file not found: %s", config$input_path))
  }

  ga_export <- utils::read.csv(config$input_path, stringsAsFactors = FALSE, check.names = FALSE)
  prepared <- normalize_ga_export(ga_export)
  prepared <- normalize_session_summary_frame(prepared, default_source = "real_user")

  output_dir <- dirname(config$output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  utils::write.csv(prepared, config$output_path, row.names = FALSE)
  cat("ga4_summary_rows=", nrow(prepared), "\n", sep = "")
  cat("output_path=", normalizePath(config$output_path, winslash = "/", mustWork = FALSE), "\n", sep = "")
}
