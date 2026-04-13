suppressPackageStartupMessages({
  library(shinytest2)
  source("utils_logging.R", local = TRUE)
  source("analyze_simulation_prep.R", local = TRUE)
})

Sys.setenv(SHINYTEST2_APP_DRIVER_TEST_ON_CRAN = "1")

default_manifest_path <- function() {
  file.path(getwd(), "data", "simulation_manifest.csv")
}

parse_simulation_args <- function(args) {
  config <- list(
    run_label = "full",
    per_variant = 100L,
    seed = as.integer(Sys.time()),
    reset_outputs = FALSE
  )

  for (arg in args) {
    if (identical(arg, "--pilot")) {
      config$run_label <- "pilot"
      config$per_variant <- 5L
      config$reset_outputs <- TRUE
    } else if (identical(arg, "--full")) {
      config$run_label <- "full"
      config$per_variant <- 100L
    } else if (grepl("^--per-variant=", arg)) {
      config$per_variant <- as.integer(sub("^--per-variant=", "", arg))
    } else if (grepl("^--seed=", arg)) {
      config$seed <- as.integer(sub("^--seed=", "", arg))
    } else if (grepl("^--label=", arg)) {
      config$run_label <- sub("^--label=", "", arg)
    } else if (identical(arg, "--reset")) {
      config$reset_outputs <- TRUE
    }
  }

  config
}

persona_profiles <- list(
  goal_oriented = list(
    A = list(
      first_action_prob = 0.86,
      continue_prob = 0.86,
      complete_prob = 0.75,
      extra_tabs = 0:1,
      delay_range = c(0.02, 0.05),
      pre_action_browse_prob = 0.15
    ),
    B = list(
      first_action_prob = 0.90,
      continue_prob = 0.88,
      complete_prob = 0.80,
      extra_tabs = 1:2,
      delay_range = c(0.03, 0.06),
      pre_action_browse_prob = 0.18
    )
  ),
  exploratory = list(
    A = list(
      first_action_prob = 0.56,
      continue_prob = 0.67,
      complete_prob = 0.40,
      extra_tabs = 1:3,
      delay_range = c(0.04, 0.09),
      pre_action_browse_prob = 0.35
    ),
    B = list(
      first_action_prob = 0.66,
      continue_prob = 0.75,
      complete_prob = 0.50,
      extra_tabs = 2:3,
      delay_range = c(0.05, 0.11),
      pre_action_browse_prob = 0.48
    )
  ),
  hesitant = list(
    A = list(
      first_action_prob = 0.15,
      continue_prob = 0.23,
      complete_prob = 0.07,
      extra_tabs = 0:1,
      delay_range = c(0.05, 0.11),
      pre_action_browse_prob = 0.10
    ),
    B = list(
      first_action_prob = 0.22,
      continue_prob = 0.32,
      complete_prob = 0.12,
      extra_tabs = 1:2,
      delay_range = c(0.06, 0.13),
      pre_action_browse_prob = 0.20
    )
  )
)

choose_persona <- function() {
  sample(names(persona_profiles), size = 1, prob = c(0.35, 0.40, 0.25))
}

balanced_persona_schedule <- function(per_variant) {
  persona_names <- c("goal_oriented", "exploratory", "hesitant")
  target_weights <- c(0.35, 0.40, 0.25)
  raw_counts <- per_variant * target_weights
  base_counts <- floor(raw_counts)
  remainder <- per_variant - sum(base_counts)

  if (remainder > 0) {
    fractional_order <- order(raw_counts - base_counts, decreasing = TRUE)
    base_counts[fractional_order[seq_len(remainder)]] <- base_counts[fractional_order[seq_len(remainder)]] + 1L
  }

  personas <- unlist(Map(rep, persona_names, base_counts), use.names = FALSE)
  sample(personas, length(personas), replace = FALSE)
}

random_delay <- function(profile) {
  range <- profile$delay_range
  Sys.sleep(runif(1, min = range[1], max = range[2]))
}

get_persona_profile <- function(persona, variant) {
  persona_profiles[[persona]][[variant]]
}

wait_for_input_if_needed <- function(app, input_name, timeout = 8000) {
  tryCatch(
    app$wait_for_value(input = input_name, timeout = timeout, ignore = list(NULL, "")),
    error = function(e) invisible(NULL)
  )
}

safe_set_inputs <- function(app, ..., wait_ = FALSE, timeout_ = 8000) {
  tryCatch(
    app$set_inputs(..., wait_ = wait_, timeout_ = timeout_),
    error = function(e) invisible(NULL)
  )
}

safe_set_inputs_list <- function(app, inputs, wait_ = FALSE, timeout_ = 8000) {
  tryCatch(
    do.call(app$set_inputs, c(inputs, list(wait_ = wait_, timeout_ = timeout_))),
    error = function(e) invisible(NULL)
  )
}

goto_tab <- function(app, variant, tab_name) {
  tab_input_id <- if (identical(variant, "A")) "main_nav_a" else "main_nav_b"
  safe_set_inputs_list(app, setNames(list(tab_name), tab_input_id), wait_ = FALSE)
  app$wait_for_idle(250)
}

pick_dataset <- function() {
  sample(c("airquality", "iris"), size = 1)
}

dataset_numeric_columns <- function(dataset_name) {
  if (identical(dataset_name, "iris")) {
    c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")
  } else {
    c("Ozone", "Solar.R", "Wind", "Temp", "Month", "Day")
  }
}

visit_extra_tabs <- function(app, variant, profile, tab_pool = c("Guide", "Data", "Cleaning", "Feature Engineering", "EDA")) {
  extra_count <- sample(profile$extra_tabs, size = 1)
  if (extra_count <= 0) {
    return(invisible(NULL))
  }

  for (tab_name in sample(tab_pool, size = extra_count, replace = TRUE)) {
    goto_tab(app, variant, tab_name)
    random_delay(profile)
  }

  invisible(NULL)
}

capture_new_session_rows <- function(log_path, previous_row_count) {
  event_log <- utils::read.csv(log_path, stringsAsFactors = FALSE)
  if (nrow(event_log) <= previous_row_count) {
    return(event_log[0, , drop = FALSE])
  }
  event_log[(previous_row_count + 1):nrow(event_log), , drop = FALSE]
}

reset_simulation_outputs <- function(
  log_path = default_event_log_path(),
  manifest_path = default_manifest_path(),
  summary_path = default_session_summary_path()
) {
  reset_event_log_file(log_path)
  reset_simulation_manifest(manifest_path)
  reset_session_summary(summary_path)
}

prune_event_log_to_manifest_runs <- function(
  log_path = default_event_log_path(),
  manifest_path = default_manifest_path()
) {
  event_log <- utils::read.csv(log_path, stringsAsFactors = FALSE)
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)

  if (!"run_label" %in% names(event_log)) {
    return(invisible(event_log))
  }

  keep_labels <- unique(manifest$run_label)
  keep_labels <- keep_labels[nzchar(keep_labels)]
  event_log <- event_log[event_log$run_label %in% keep_labels, , drop = FALSE]
  utils::write.csv(event_log, log_path, row.names = FALSE)
  invisible(event_log)
}

append_manifest_row <- function(manifest_path, session_id, variant, persona, run_label, planned_dataset) {
  ensure_simulation_manifest(manifest_path)
  row <- data.frame(
    session_id = session_id,
    variant = variant,
    persona = persona,
    run_label = run_label,
    planned_dataset = planned_dataset,
    stringsAsFactors = FALSE
  )
  utils::write.table(
    row,
    file = manifest_path,
    sep = ",",
    row.names = FALSE,
    col.names = FALSE,
    append = TRUE,
    qmethod = "double"
  )
}

run_ab_app <- function() {
  source("app_abtest.R", local = TRUE)
  app
}

start_test_server <- function() {
  Sys.setenv(ABTEST_RUN_LABEL = "bootstrap")
  shinytest2::AppDriver$new(
    app_dir = run_ab_app,
    name = NULL,
    load_timeout = 20000
  )
}

run_one_session <- function(base_url, variant, persona, run_label, log_path, manifest_path, session_index) {
  profile <- get_persona_profile(persona, variant)
  dataset_name <- pick_dataset()
  tab_input_id <- if (identical(variant, "A")) "main_nav_a" else "main_nav_b"
  before_log <- utils::read.csv(log_path, stringsAsFactors = FALSE)
  before_rows <- nrow(before_log)

  app <- shinytest2::AppDriver$new(
    app_dir = paste0(base_url, "?variant=", variant, "&run_label=", utils::URLencode(run_label, reserved = TRUE)),
    name = NULL,
    height = 1100,
    width = 1440,
    load_timeout = 20000
  )

  on.exit(
    tryCatch({
      app$stop()
    }, error = function(e) invisible(NULL)),
    add = TRUE
  )

  app$wait_for_idle(300)
  wait_for_input_if_needed(app, tab_input_id, timeout = 12000)
  random_delay(profile)

  took_first_action <- stats::runif(1) < profile$first_action_prob
  continued <- took_first_action && stats::runif(1) < profile$continue_prob
  completed <- continued && stats::runif(1) < profile$complete_prob

  if (!took_first_action) {
    browse_pool <- if (identical(persona, "exploratory")) c("Guide", "Data") else "Guide"
    visit_extra_tabs(app, variant, profile, tab_pool = browse_pool)
    random_delay(profile)
  }

  if (took_first_action) {
    if (stats::runif(1) < profile$pre_action_browse_prob) {
      visit_extra_tabs(app, variant, profile, tab_pool = c("Guide", "Data"))
    }
    goto_tab(app, variant, "Data")
    wait_for_input_if_needed(app, "source_type")
    safe_set_inputs(app, source_type = "Built-in dataset", wait_ = FALSE)
    app$wait_for_idle(150)
    wait_for_input_if_needed(app, "builtin_name")
    safe_set_inputs(app, builtin_name = dataset_name, timeout_ = 8000)
    app$wait_for_idle(250)
    random_delay(profile)
  }

  if (continued) {
    numeric_cols <- dataset_numeric_columns(dataset_name)
    goto_tab(app, variant, "Cleaning")
    cleaning_action <- sample(
      c("remove_duplicates", "coerce_date_columns", "standardize_names"),
      size = 1
    )
    if (identical(cleaning_action, "remove_duplicates")) {
      safe_set_inputs(app, remove_duplicates = TRUE, timeout_ = 8000)
    } else if (identical(cleaning_action, "coerce_date_columns")) {
      safe_set_inputs(app, coerce_date_columns = TRUE, timeout_ = 8000)
    } else {
      safe_set_inputs(app, standardize_names = !identical(dataset_name, "airquality"), timeout_ = 8000)
    }
    app$wait_for_idle(250)
    random_delay(profile)

    if (completed || identical(persona, "exploratory")) {
      goto_tab(app, variant, "Feature Engineering")
      feature_name <- paste0("sim_feature_", variant, "_", session_index)
      selected_num_col <- numeric_cols[1]
      safe_set_inputs(app, feature_action = "Log transform", timeout_ = 8000)
      wait_for_input_if_needed(app, "feature_num_col")
      safe_set_inputs(app, feature_num_col = selected_num_col, wait_ = FALSE)
      safe_set_inputs(app, new_feature_name = feature_name, timeout_ = 8000)
      random_delay(profile)
      tryCatch(app$click("add_feature"), error = function(e) invisible(NULL))
      app$wait_for_idle(350)
      random_delay(profile)
    }
  }

  if (completed) {
    numeric_cols <- dataset_numeric_columns(dataset_name)
    goto_tab(app, variant, "EDA")
    if (identical(dataset_name, "iris")) {
      safe_set_inputs(app, plot_type = "Scatter plot", timeout_ = 8000)
      wait_for_input_if_needed(app, "plot_x")
      wait_for_input_if_needed(app, "plot_y")
      safe_set_inputs(
        app,
        plot_x = numeric_cols[1],
        plot_y = numeric_cols[2],
        timeout_ = 8000
      )
    } else {
      safe_set_inputs(app, plot_type = "Histogram", timeout_ = 8000)
      wait_for_input_if_needed(app, "plot_x")
      safe_set_inputs(app, plot_x = numeric_cols[1], timeout_ = 8000)
    }
    app$wait_for_idle(500)
    random_delay(profile)
  }

  if (identical(persona, "exploratory")) {
    visit_extra_tabs(app, variant, profile)
  }

  app$stop()
  Sys.sleep(0.2)

  new_rows <- capture_new_session_rows(log_path, before_rows)
  if (!"run_label" %in% names(new_rows)) {
    new_rows$run_label <- ""
  }
  new_rows <- new_rows[new_rows$run_label == run_label, , drop = FALSE]
  session_ids <- unique(new_rows$session_id)
  session_ids <- session_ids[nzchar(session_ids)]

  if (!length(session_ids)) {
    stop("No new session rows were found in event_log.csv after a simulated session.")
  }

  session_id <- session_ids[length(session_ids)]
  append_manifest_row(
    manifest_path = manifest_path,
    session_id = session_id,
    variant = variant,
    persona = persona,
    run_label = run_label,
    planned_dataset = dataset_name
  )

  data.frame(
    session_id = session_id,
    variant = variant,
    persona = persona,
    planned_dataset = dataset_name,
    stringsAsFactors = FALSE
  )
}

run_simulation_batch <- function(config) {
  set.seed(config$seed)
  log_path <- default_event_log_path()
  manifest_path <- default_manifest_path()
  summary_path <- default_session_summary_path()

  if (isTRUE(config$reset_outputs)) {
    reset_simulation_outputs(log_path, manifest_path, summary_path)
  } else {
    ensure_event_log_file(log_path)
    ensure_simulation_manifest(manifest_path)
    ensure_session_summary(summary_path)
  }

  app_process <- start_test_server()
  on.exit(
    tryCatch({
      app_process$stop()
    }, error = function(e) invisible(NULL)),
    add = TRUE
  )

  base_url <- app_process$get_url()
  session_records <- list()
  session_counter <- 1L
  persona_plan <- list()

  if (identical(config$run_label, "full")) {
    shared_schedule <- balanced_persona_schedule(config$per_variant)
    persona_plan$A <- sample(shared_schedule, length(shared_schedule), replace = FALSE)
    persona_plan$B <- sample(shared_schedule, length(shared_schedule), replace = FALSE)
  }

  for (variant in c("A", "B")) {
    for (i in seq_len(config$per_variant)) {
      persona <- if (identical(config$run_label, "full")) persona_plan[[variant]][i] else choose_persona()
      message(sprintf("[%s] Running variant %s session %d/%d as %s", config$run_label, variant, i, config$per_variant, persona))
      session_records[[length(session_records) + 1L]] <- run_one_session(
        base_url = base_url,
        variant = variant,
        persona = persona,
        run_label = config$run_label,
        log_path = log_path,
        manifest_path = manifest_path,
        session_index = session_counter
      )
      session_counter <- session_counter + 1L
    }
  }

  build_session_summary(
    log_path = log_path,
    manifest_path = manifest_path,
    summary_path = summary_path
  )

  prune_event_log_to_manifest_runs(
    log_path = log_path,
    manifest_path = manifest_path
  )

  do.call(rbind, session_records)
}

if (sys.nframe() == 0) {
  config <- parse_simulation_args(commandArgs(trailingOnly = TRUE))
  session_records <- run_simulation_batch(config)
  counts <- table(session_records$variant)
  cat("simulation_run_label=", config$run_label, "\n", sep = "")
  cat("sessions_variant_A=", counts[["A"]] %||% 0, "\n", sep = "")
  cat("sessions_variant_B=", counts[["B"]] %||% 0, "\n", sep = "")
}
