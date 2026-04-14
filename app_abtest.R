source("utils_logging.R", local = TRUE)
source("shared_logic.R", local = TRUE)
source("ui_variant_a.R", local = TRUE)
source("ui_variant_b.R", local = TRUE)

ensure_legacy_simulated_data_migrated()

ui_abtest <- function(request) {
  tagList(
    google_analytics_head(),
    uiOutput("assigned_ui")
  )
}

make_ab_server <- function(
  query_override = NULL,
  data_source = "simulated",
  log_path = default_event_log_path(data_source),
  session_summary_path = NULL,
  live_session_summary = FALSE,
  default_run_label = Sys.getenv("ABTEST_RUN_LABEL", unset = "")
) {
  function(input, output, session) {
    normalized_data_source <- normalize_data_source(data_source)
    ensure_event_log_file(log_path)
    if (isTRUE(live_session_summary) && !is.null(session_summary_path)) {
      ensure_session_summary_file(session_summary_path)
    }

    query_string <- query_override %||% isolate(session$clientData$url_search %||% "")
    parsed_query <- shiny::parseQueryString(query_string %||% "")
    assignment <- resolve_variant_assignment(query_string)

    session$userData$variant <- assignment$variant
    session$userData$session_id <- make_session_id()
    session$userData$start_time <- Sys.time()
    session$userData$data_source <- normalized_data_source
    session$userData$run_label <- parsed_query$run_label %||% default_run_label
    session$userData$log_path <- log_path
    session$userData$summary_path <- session_summary_path
    session$userData$ga_enabled <- ga_enabled()
    session$userData$logging_enabled <- TRUE
    session$userData$event_count <- 0L
    session$userData$persona <- NA_character_
    session$userData$first_key_action_logged <- FALSE
    session$userData$dataset_loaded <- FALSE
    session$userData$cleaning_applied <- FALSE
    session$userData$feature_engineering_applied <- FALSE
    session$userData$eda_generated <- FALSE
    session$userData$task_completed_logged <- FALSE
    session$userData$last_tab <- "Guide"
    session$userData$last_tracked_tab <- NULL
    session$userData$ga_context_ready <- FALSE

    log_session_event(
      session = session,
      event_name = "session_start",
      event_value = paste0("assignment_mode=", assignment$assignment_mode, ";variant=", assignment$variant),
      tab_name = "Guide"
    )

    output$assigned_ui <- renderUI({
      if (identical(session$userData$variant, "A")) {
        ui_variant_a()
      } else {
        ui_variant_b()
      }
    })

    observe({
      active_tab <- input$main_nav_a %||% input$main_nav_b %||% "Guide"
      session$userData$last_tab <- active_tab
      previous_tab <- session$userData$last_tracked_tab %||% ""
      if (isTRUE(session$userData$ga_context_ready %||% FALSE) &&
          !identical(active_tab, session$userData$last_tracked_tab)) {
        set_google_analytics_context(
          session = session,
          tab_name = active_tab,
          send_page_view = TRUE
        )
        send_google_analytics_event(
          session = session,
          event_name = "tab_view",
          tab_name = active_tab,
          extra_params = list(previous_tab = ga_param_value(previous_tab))
        )
        session$userData$last_tracked_tab <- active_tab
      }
    })

    session$onFlushed(function() {
      set_google_analytics_context(
        session = session,
        assignment_mode = assignment$assignment_mode,
        tab_name = "Guide",
        send_page_view = TRUE
      )
      session$userData$ga_context_ready <- TRUE
      session$userData$last_tracked_tab <- "Guide"
      log_session_event(
        session = session,
        event_name = "landing_view",
        event_value = paste0("variant=", session$userData$variant),
        tab_name = "Guide"
      )
    }, once = TRUE)

    session$onSessionEnded(function() {
      duration_seconds <- round(as.numeric(difftime(Sys.time(), session$userData$start_time, units = "secs")), 2)
      log_session_event(
        session = session,
        event_name = "session_end",
        event_value = paste0("duration_seconds=", duration_seconds),
        tab_name = session$userData$last_tab %||% ""
      )
      if (isTRUE(live_session_summary) && !is.null(session_summary_path)) {
        append_session_summary_row(
          session = session,
          summary_path = session_summary_path,
          persona = NA_character_,
          session_duration = duration_seconds
        )
      }
    })

    shared_server(input, output, session)
  }
}

app <- shinyApp(
  ui = ui_abtest,
  server = make_ab_server(
    data_source = "simulated",
    log_path = default_event_log_path("simulated")
  )
)

if (interactive()) {
  print(app)
}
