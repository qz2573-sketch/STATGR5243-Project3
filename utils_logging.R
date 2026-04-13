`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

default_event_log_path <- function() {
  file.path(getwd(), "data", "event_log.csv")
}

ensure_event_log_file <- function(log_path = default_event_log_path()) {
  log_dir <- dirname(log_path)
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }

  if (!file.exists(log_path)) {
    header <- event_log_header()
    utils::write.csv(header, log_path, row.names = FALSE)
  }

  invisible(log_path)
}

event_log_header <- function() {
  data.frame(
    session_id = character(),
    variant = character(),
    run_label = character(),
    timestamp = character(),
    event_name = character(),
    event_value = character(),
    tab_name = character(),
    stringsAsFactors = FALSE
  )
}

reset_event_log_file <- function(log_path = default_event_log_path()) {
  log_dir <- dirname(log_path)
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }

  utils::write.csv(event_log_header(), log_path, row.names = FALSE)
  invisible(log_path)
}

make_session_id <- function() {
  paste0(
    format(Sys.time(), "%Y%m%d%H%M%S"),
    "-",
    paste(sample(c(letters, LETTERS, 0:9), 10, replace = TRUE), collapse = "")
  )
}

resolve_variant_assignment <- function(query_string = NULL) {
  parsed_query <- shiny::parseQueryString(query_string %||% "")
  forced_variant <- toupper(parsed_query$variant %||% "")

  if (forced_variant %in% c("A", "B")) {
    return(list(variant = forced_variant, assignment_mode = "query_override"))
  }

  list(
    variant = sample(c("A", "B"), size = 1),
    assignment_mode = "random"
  )
}

log_session_event <- function(session, event_name, event_value = NULL, tab_name = NULL, log_path = NULL) {
  logging_enabled <- isTRUE(session$userData$logging_enabled %||% FALSE)
  if (!logging_enabled) {
    return(invisible(FALSE))
  }

  target_path <- log_path %||% session$userData$log_path %||% default_event_log_path()

  tryCatch({
    ensure_event_log_file(target_path)
    row <- data.frame(
      session_id = as.character(session$userData$session_id %||% ""),
      variant = as.character(session$userData$variant %||% ""),
      run_label = as.character(session$userData$run_label %||% ""),
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = ""),
      event_name = as.character(event_name %||% ""),
      event_value = as.character(event_value %||% ""),
      tab_name = as.character(tab_name %||% ""),
      stringsAsFactors = FALSE
    )
    utils::write.table(
      row,
      file = target_path,
      sep = ",",
      row.names = FALSE,
      col.names = FALSE,
      append = TRUE,
      qmethod = "double"
    )
    invisible(TRUE)
  }, error = function(e) {
    warning(sprintf("Event logging failed for '%s': %s", event_name, conditionMessage(e)), call. = FALSE)
    invisible(FALSE)
  })
}

log_first_key_action_once <- function(session, trigger_event, event_value = NULL, tab_name = NULL) {
  if (isTRUE(session$userData$first_key_action_logged %||% FALSE)) {
    return(invisible(FALSE))
  }

  session$userData$first_key_action_logged <- TRUE
  log_session_event(
    session = session,
    event_name = "first_key_action",
    event_value = paste(trigger_event, event_value %||% "", sep = if (is.null(event_value)) "" else ":"),
    tab_name = tab_name
  )
  invisible(TRUE)
}

check_and_log_task_completed <- function(session, tab_name = NULL) {
  if (isTRUE(session$userData$task_completed_logged %||% FALSE)) {
    return(invisible(FALSE))
  }

  required_flags <- c(
    isTRUE(session$userData$dataset_loaded %||% FALSE),
    isTRUE(session$userData$cleaning_applied %||% FALSE),
    isTRUE(session$userData$feature_engineering_applied %||% FALSE),
    isTRUE(session$userData$eda_generated %||% FALSE)
  )

  if (all(required_flags)) {
    session$userData$task_completed_logged <- TRUE
    log_session_event(
      session = session,
      event_name = "task_completed",
      event_value = "dataset_loaded+cleaning+feature_engineering+eda",
      tab_name = tab_name
    )
    return(invisible(TRUE))
  }

  invisible(FALSE)
}
