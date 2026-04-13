source("utils_logging.R", local = TRUE)
source("shared_logic.R", local = TRUE)
source("ui_variant_a.R", local = TRUE)
source("ui_variant_b.R", local = TRUE)

ui_abtest <- function(request) {
  tagList(
    uiOutput("assigned_ui")
  )
}

make_ab_server <- function(query_override = NULL, log_path = default_event_log_path()) {
  function(input, output, session) {
    ensure_event_log_file(log_path)

    query_string <- query_override %||% isolate(session$clientData$url_search %||% "")
    parsed_query <- shiny::parseQueryString(query_string %||% "")
    assignment <- resolve_variant_assignment(query_string)

    session$userData$variant <- assignment$variant
    session$userData$session_id <- make_session_id()
    session$userData$start_time <- Sys.time()
    session$userData$run_label <- parsed_query$run_label %||% Sys.getenv("ABTEST_RUN_LABEL", unset = "")
    session$userData$log_path <- log_path
    session$userData$logging_enabled <- TRUE
    session$userData$first_key_action_logged <- FALSE
    session$userData$dataset_loaded <- FALSE
    session$userData$cleaning_applied <- FALSE
    session$userData$feature_engineering_applied <- FALSE
    session$userData$eda_generated <- FALSE
    session$userData$task_completed_logged <- FALSE
    session$userData$last_tab <- "Guide"

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
    })

    session$onFlushed(function() {
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
    })

    shared_server(input, output, session)
  }
}

app <- shinyApp(
  ui = ui_abtest,
  server = make_ab_server()
)

if (interactive()) {
  print(app)
}
