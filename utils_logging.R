`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

default_data_source <- function() {
  normalize_data_source(Sys.getenv("ABTEST_DATA_SOURCE", unset = "simulated"))
}

ga_measurement_id <- function() {
  env_value <- trimws(Sys.getenv("GA4_MEASUREMENT_ID", unset = ""))
  if (nzchar(env_value)) {
    return(env_value)
  }
  "G-5XYRDJLPHH"
}

ga_enabled <- function() {
  nzchar(ga_measurement_id())
}

normalize_ga_event_name <- function(event_name) {
  normalized <- tolower(gsub("[^A-Za-z0-9_]+", "_", event_name %||% ""))
  normalized <- gsub("_+", "_", normalized)
  normalized <- gsub("^_|_$", "", normalized)
  if (!nzchar(normalized)) {
    normalized <- "shiny_event"
  }
  if (!grepl("^[A-Za-z]", normalized)) {
    normalized <- paste0("event_", normalized)
  }
  substr(normalized, 1, 40)
}

normalize_ga_slug <- function(value, fallback = "unknown") {
  normalized <- tolower(gsub("[^A-Za-z0-9]+", "-", value %||% ""))
  normalized <- gsub("-+", "-", normalized)
  normalized <- gsub("^-|-$", "", normalized)
  if (!nzchar(normalized)) {
    normalized <- fallback
  }
  substr(normalized, 1, 60)
}

compact_list <- function(x) {
  Filter(Negate(is.null), x)
}

ga_param_value <- function(value) {
  if (is.null(value) || !length(value)) {
    return(NULL)
  }
  first_value <- value[[1]]
  if (is.numeric(first_value) || is.logical(first_value)) {
    return(unname(first_value))
  }
  if (is.na(first_value)) {
    return(NULL)
  }
  as.character(first_value)
}

google_analytics_head <- function() {
  measurement_id <- ga_measurement_id()
  if (!nzchar(measurement_id)) {
    return(NULL)
  }

  shiny::tagList(
    shiny::tags$script(async = NA, src = sprintf("https://www.googletagmanager.com/gtag/js?id=%s", measurement_id)),
    shiny::tags$script(shiny::HTML(sprintf(
      "window.dataLayer = window.dataLayer || [];
function gtag(){dataLayer.push(arguments);}
gtag('js', new Date());
gtag('config', '%s');
window.dataPilotGaState = window.dataPilotGaState || {
  sessionStartMs: null,
  heartbeatTimer: null,
  heartbeatCount: 0,
  summarySent: false,
  sessionId: null,
  variant: null,
  runLabel: null,
  dataSource: null,
  currentTab: 'Guide',
  eventCount: 0,
  firstKeyActionTaken: false,
  taskCompleted: false,
  persona: 'NA'
};
function buildDataPilotParams(extra) {
  var state = window.dataPilotGaState || {};
  var base = {
    session_id: state.sessionId,
    variant: state.variant,
    run_label: state.runLabel,
    data_source: state.dataSource,
    tab_name: state.currentTab
  };
  var merged = Object.assign({}, base, extra || {});
  Object.keys(merged).forEach(function(key) {
    if (merged[key] === null || merged[key] === undefined || merged[key] === '') {
      delete merged[key];
    }
  });
  return merged;
}
function ensureDataPilotHeartbeat() {
  var state = window.dataPilotGaState;
  if (!state || state.heartbeatTimer) {
    return;
  }
  state.sessionStartMs = state.sessionStartMs || Date.now();
  state.heartbeatTimer = window.setInterval(function() {
    var elapsedSeconds = Math.round((Date.now() - state.sessionStartMs) / 1000);
    state.heartbeatCount += 1;
    gtag('event', 'session_progress', buildDataPilotParams({
      session_duration_seconds: elapsedSeconds,
      session_duration: elapsedSeconds,
      heartbeat_index: state.heartbeatCount
    }));
  }, 10000);
}
function sendDataPilotSessionSummary(reason) {
  var state = window.dataPilotGaState;
  if (!state || state.summarySent || !state.sessionStartMs) {
    return;
  }
  state.summarySent = true;
  if (state.heartbeatTimer) {
    window.clearInterval(state.heartbeatTimer);
    state.heartbeatTimer = null;
  }
  var elapsedSeconds = Math.round((Date.now() - state.sessionStartMs) / 1000);
  gtag('event', 'session_summary', buildDataPilotParams({
    persona: state.persona || 'NA',
    first_key_action_taken: state.firstKeyActionTaken,
    task_completed: state.taskCompleted,
    session_duration_seconds: elapsedSeconds,
    session_duration: elapsedSeconds,
    num_events: state.eventCount,
    exit_reason: reason,
    transport_type: 'beacon'
  }));
}
window.addEventListener('pagehide', function() {
  sendDataPilotSessionSummary('pagehide');
});
document.addEventListener('visibilitychange', function() {
  if (document.visibilityState === 'hidden') {
    sendDataPilotSessionSummary('hidden');
  }
});
if (window.Shiny) {
  Shiny.addCustomMessageHandler('ga_context', function(payload) {
    payload = payload || {};
    var state = window.dataPilotGaState;
    var pageViewParams = payload.page_view_params || {};
    if (pageViewParams.session_id) {
      state.sessionId = pageViewParams.session_id;
    }
    if (pageViewParams.variant) {
      state.variant = pageViewParams.variant;
    }
    if (pageViewParams.run_label) {
      state.runLabel = pageViewParams.run_label;
    }
    if (pageViewParams.data_source) {
      state.dataSource = pageViewParams.data_source;
    }
    if (pageViewParams.tab_name) {
      state.currentTab = pageViewParams.tab_name;
    }
    state.sessionStartMs = state.sessionStartMs || Date.now();
    ensureDataPilotHeartbeat();
    var userProperties = payload.user_properties || {};
    if (Object.keys(userProperties).length > 0) {
      gtag('set', 'user_properties', userProperties);
    }
    if (payload.page_title) {
      document.title = payload.page_title;
    }
    if (payload.page_view_params) {
      gtag('event', 'page_view', buildDataPilotParams(payload.page_view_params));
    }
  });
  Shiny.addCustomMessageHandler('ga_event', function(payload) {
    if (!payload || !payload.event_name) {
      return;
    }
    var state = window.dataPilotGaState;
    var params = payload.params || {};
    if (params.session_id) {
      state.sessionId = params.session_id;
    }
    if (params.variant) {
      state.variant = params.variant;
    }
    if (params.run_label) {
      state.runLabel = params.run_label;
    }
    if (params.data_source) {
      state.dataSource = params.data_source;
    }
    if (params.tab_name) {
      state.currentTab = params.tab_name;
    }
    if (params.persona) {
      state.persona = params.persona;
    }
    if (typeof params.event_count === 'number') {
      state.eventCount = params.event_count;
    }
    if (payload.event_name === 'first_key_action') {
      state.firstKeyActionTaken = true;
    }
    if (payload.event_name === 'task_completed') {
      state.taskCompleted = true;
    }
    state.sessionStartMs = state.sessionStartMs || Date.now();
    ensureDataPilotHeartbeat();
    gtag('event', payload.event_name, buildDataPilotParams(params));
  });
}",
      measurement_id
    )))
  )
}

normalize_data_source <- function(data_source = NULL) {
  normalized <- tolower(trimws(as.character(data_source %||% "")))
  if (identical(normalized, "real")) {
    normalized <- "real_user"
  }
  if (!normalized %in% c("simulated", "real_user")) {
    normalized <- "simulated"
  }
  normalized
}

data_root_dir <- function() {
  file.path(getwd(), "data")
}

simulated_data_dir <- function() {
  file.path(data_root_dir(), "simulated")
}

real_data_dir <- function() {
  file.path(data_root_dir(), "real")
}

analysis_data_dir <- function() {
  file.path(data_root_dir(), "analysis")
}

legacy_event_log_path <- function() {
  file.path(data_root_dir(), "event_log.csv")
}

legacy_session_summary_path <- function() {
  file.path(data_root_dir(), "session_summary.csv")
}

legacy_simulation_manifest_path <- function() {
  file.path(data_root_dir(), "simulation_manifest.csv")
}

default_simulation_manifest_path <- function() {
  file.path(simulated_data_dir(), "simulation_manifest_simulated.csv")
}

default_event_log_path <- function(data_source = default_data_source()) {
  normalized <- normalize_data_source(data_source)
  if (identical(normalized, "real_user")) {
    return(file.path(real_data_dir(), "event_log_real.csv"))
  }
  file.path(simulated_data_dir(), "event_log_simulated.csv")
}

default_session_summary_path <- function(data_source = default_data_source()) {
  normalized <- normalize_data_source(data_source)
  if (identical(normalized, "real_user")) {
    return(file.path(real_data_dir(), "session_summary_real.csv"))
  }
  file.path(simulated_data_dir(), "session_summary_simulated.csv")
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
    data_source = character(),
    stringsAsFactors = FALSE
  )
}

session_summary_header <- function() {
  data.frame(
    session_id = character(),
    variant = character(),
    persona = character(),
    run_label = character(),
    data_source = character(),
    first_key_action_taken = logical(),
    task_completed = logical(),
    session_duration = numeric(),
    num_events = integer(),
    stringsAsFactors = FALSE
  )
}

default_combined_session_summary_path <- function() {
  file.path(analysis_data_dir(), "session_summary_combined.csv")
}

ensure_data_directories <- function() {
  for (dir_path in c(data_root_dir(), simulated_data_dir(), real_data_dir(), analysis_data_dir())) {
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
    }
  }
  invisible(TRUE)
}

copy_file_if_missing <- function(source_path, target_path) {
  if (!file.exists(source_path) || file.exists(target_path)) {
    return(invisible(FALSE))
  }
  ensure_data_directories()
  file.copy(source_path, target_path, overwrite = FALSE)
  invisible(TRUE)
}

ensure_legacy_simulated_data_migrated <- function() {
  ensure_data_directories()
  copy_file_if_missing(legacy_event_log_path(), default_event_log_path("simulated"))
  copy_file_if_missing(legacy_session_summary_path(), default_session_summary_path("simulated"))
  copy_file_if_missing(legacy_simulation_manifest_path(), default_simulation_manifest_path())
  invisible(TRUE)
}

normalize_event_log_frame <- function(df, default_source = "simulated") {
  template <- event_log_header()
  if (!nrow(df)) {
    return(template[0, , drop = FALSE])
  }

  missing_cols <- setdiff(names(template), names(df))
  for (col_name in missing_cols) {
    template_value <- template[[col_name]]
    fill_value <- if (is.logical(template_value)) {
      rep(FALSE, nrow(df))
    } else if (is.numeric(template_value)) {
      rep(NA_real_, nrow(df))
    } else if (is.integer(template_value)) {
      rep(0L, nrow(df))
    } else {
      rep("", nrow(df))
    }
    df[[col_name]] <- fill_value
  }

  df <- df[, names(template), drop = FALSE]
  blank_sources <- is.na(df$data_source) | !nzchar(df$data_source)
  df$data_source[blank_sources] <- normalize_data_source(default_source)
  df$data_source <- vapply(df$data_source, normalize_data_source, character(1))
  df
}

normalize_session_summary_frame <- function(df, default_source = "simulated") {
  template <- session_summary_header()
  if (!nrow(df)) {
    return(template[0, , drop = FALSE])
  }

  missing_cols <- setdiff(names(template), names(df))
  for (col_name in missing_cols) {
    template_value <- template[[col_name]]
    fill_value <- if (is.logical(template_value)) {
      rep(FALSE, nrow(df))
    } else if (is.numeric(template_value)) {
      rep(NA_real_, nrow(df))
    } else if (is.integer(template_value)) {
      rep(0L, nrow(df))
    } else {
      rep("", nrow(df))
    }
    df[[col_name]] <- fill_value
  }

  df <- df[, names(template), drop = FALSE]
  blank_sources <- is.na(df$data_source) | !nzchar(df$data_source)
  df$data_source[blank_sources] <- normalize_data_source(default_source)
  df$data_source <- vapply(df$data_source, normalize_data_source, character(1))
  df
}

ensure_event_log_file <- function(log_path = default_event_log_path()) {
  ensure_data_directories()

  if (!file.exists(log_path)) {
    utils::write.csv(event_log_header(), log_path, row.names = FALSE)
    return(invisible(log_path))
  }

  existing <- utils::read.csv(log_path, stringsAsFactors = FALSE)
  normalized <- normalize_event_log_frame(existing, default_source = infer_data_source_from_path(log_path))
  if (!identical(names(existing), names(normalized)) || ncol(existing) != ncol(normalized)) {
    utils::write.csv(normalized, log_path, row.names = FALSE)
  }

  invisible(log_path)
}

reset_event_log_file <- function(log_path = default_event_log_path()) {
  ensure_data_directories()
  normalized_source <- infer_data_source_from_path(log_path)
  header <- event_log_header()
  if (identical(normalized_source, "real_user")) {
    header$data_source <- character()
  }
  utils::write.csv(header, log_path, row.names = FALSE)
  invisible(log_path)
}

ensure_session_summary_file <- function(summary_path = default_session_summary_path()) {
  ensure_data_directories()

  if (!file.exists(summary_path)) {
    utils::write.csv(session_summary_header(), summary_path, row.names = FALSE)
    return(invisible(summary_path))
  }

  existing <- utils::read.csv(summary_path, stringsAsFactors = FALSE)
  normalized <- normalize_session_summary_frame(existing, default_source = infer_data_source_from_path(summary_path))
  if (!identical(names(existing), names(normalized)) || ncol(existing) != ncol(normalized)) {
    utils::write.csv(normalized, summary_path, row.names = FALSE)
  }

  invisible(summary_path)
}

reset_session_summary <- function(summary_path = default_session_summary_path()) {
  ensure_data_directories()
  utils::write.csv(session_summary_header(), summary_path, row.names = FALSE)
  invisible(summary_path)
}

infer_data_source_from_path <- function(path) {
  base_name <- tolower(basename(path %||% ""))
  if (grepl("real", base_name, fixed = TRUE)) {
    return("real_user")
  }
  "simulated"
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

append_csv_row <- function(row, target_path) {
  utils::write.table(
    row,
    file = target_path,
    sep = ",",
    row.names = FALSE,
    col.names = FALSE,
    append = TRUE,
    qmethod = "double"
  )
}

send_google_analytics_event <- function(session, event_name, event_value = NULL, tab_name = NULL, extra_params = list()) {
  if (!isTRUE(session$userData$ga_enabled %||% FALSE)) {
    return(invisible(FALSE))
  }

  params <- compact_list(c(
    list(
      session_id = ga_param_value(session$userData$session_id %||% NULL),
      variant = ga_param_value(session$userData$variant %||% NULL),
      run_label = ga_param_value(session$userData$run_label %||% NULL),
      data_source = ga_param_value(session$userData$data_source %||% NULL),
      tab_name = ga_param_value(tab_name),
      event_value = ga_param_value(event_value)
    ),
    extra_params
  ))

  tryCatch({
    session$sendCustomMessage(
      type = "ga_event",
      message = list(
        event_name = normalize_ga_event_name(event_name),
        params = params
      )
    )
    invisible(TRUE)
  }, error = function(e) {
    invisible(FALSE)
  })
}

set_google_analytics_context <- function(session, assignment_mode = NULL, tab_name = NULL, send_page_view = TRUE) {
  if (!isTRUE(session$userData$ga_enabled %||% FALSE)) {
    return(invisible(FALSE))
  }

  variant <- as.character(session$userData$variant %||% "")
  variant_slug <- tolower(paste0("variant-", variant))
  active_tab <- as.character(tab_name %||% session$userData$last_tab %||% "Guide")
  tab_slug <- normalize_ga_slug(active_tab, fallback = "guide")
  page_title <- paste("DataPilot", variant, "|", active_tab)
  page_location <- paste0("/", variant_slug, "/", tab_slug)
  page_view_params <- if (isTRUE(send_page_view)) compact_list(list(
    page_title = page_title,
    page_location = page_location,
    page_path = page_location,
    session_id = ga_param_value(session$userData$session_id %||% NULL),
    variant = ga_param_value(variant),
    tab_name = ga_param_value(active_tab),
    run_label = ga_param_value(session$userData$run_label %||% NULL),
    data_source = ga_param_value(session$userData$data_source %||% NULL)
  )) else NULL

  tryCatch({
    session$sendCustomMessage(
      type = "ga_context",
      message = list(
        user_properties = compact_list(list(
          variant = ga_param_value(variant),
          current_tab = ga_param_value(active_tab),
          run_label = ga_param_value(session$userData$run_label %||% NULL),
          data_source = ga_param_value(session$userData$data_source %||% NULL)
        )),
        page_title = page_title,
        page_view_params = page_view_params
      )
    )
    send_google_analytics_event(
      session = session,
      event_name = "experiment_assignment",
      tab_name = active_tab,
      extra_params = compact_list(list(
        assignment_mode = ga_param_value(assignment_mode),
        variant = ga_param_value(variant),
        virtual_page = ga_param_value(page_location),
        page_variant = ga_param_value(variant_slug),
        page_tab = ga_param_value(tab_slug)
      ))
    )
    invisible(TRUE)
  }, error = function(e) {
    invisible(FALSE)
  })
}

send_google_analytics_session_summary <- function(session, session_duration = NULL, tab_name = NULL) {
  if (!isTRUE(session$userData$ga_enabled %||% FALSE)) {
    return(invisible(FALSE))
  }

  send_google_analytics_event(
    session = session,
    event_name = "session_summary",
    tab_name = tab_name %||% session$userData$last_tab %||% "Guide",
    extra_params = compact_list(list(
      persona = ga_param_value(session$userData$persona %||% "NA"),
      first_key_action_taken = isTRUE(session$userData$first_key_action_logged %||% FALSE),
      task_completed = isTRUE(session$userData$task_completed_logged %||% FALSE),
      session_duration = as.numeric(session_duration %||% NA_real_),
      num_events = as.integer(session$userData$event_count %||% 0L)
    ))
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
      data_source = as.character(normalize_data_source(session$userData$data_source %||% infer_data_source_from_path(target_path))),
      stringsAsFactors = FALSE
    )
    append_csv_row(row, target_path)
    session$userData$event_count <- as.integer(session$userData$event_count %||% 0L) + 1L
    send_google_analytics_event(
      session = session,
      event_name = event_name,
      event_value = event_value,
      tab_name = tab_name,
      extra_params = list(event_count = session$userData$event_count)
    )
    invisible(TRUE)
  }, error = function(e) {
    warning(sprintf("Event logging failed for '%s': %s", event_name, conditionMessage(e)), call. = FALSE)
    invisible(FALSE)
  })
}

append_session_summary_row <- function(session, summary_path = NULL, persona = NA_character_, session_duration = NULL) {
  target_path <- summary_path %||% session$userData$summary_path %||% default_session_summary_path(session$userData$data_source %||% "simulated")

  tryCatch({
    ensure_session_summary_file(target_path)
    row <- data.frame(
      session_id = as.character(session$userData$session_id %||% ""),
      variant = as.character(session$userData$variant %||% ""),
      persona = as.character(persona %||% NA_character_),
      run_label = as.character(session$userData$run_label %||% ""),
      data_source = as.character(normalize_data_source(session$userData$data_source %||% infer_data_source_from_path(target_path))),
      first_key_action_taken = isTRUE(session$userData$first_key_action_logged %||% FALSE),
      task_completed = isTRUE(session$userData$task_completed_logged %||% FALSE),
      session_duration = as.numeric(session_duration %||% NA_real_),
      num_events = as.integer(session$userData$event_count %||% 0L),
      stringsAsFactors = FALSE
    )
    append_csv_row(row, target_path)
    invisible(TRUE)
  }, error = function(e) {
    warning(sprintf("Session summary logging failed: %s", conditionMessage(e)), call. = FALSE)
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
