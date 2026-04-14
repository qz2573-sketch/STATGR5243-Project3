source("app_abtest.R", local = TRUE)

app <- shinyApp(
  ui = ui_abtest,
  server = make_ab_server(
    data_source = "real_user",
    log_path = default_event_log_path("real_user"),
    session_summary_path = default_session_summary_path("real_user"),
    live_session_summary = TRUE,
    default_run_label = Sys.getenv("ABTEST_RUN_LABEL", unset = "production")
  )
)

if (interactive()) {
  print(app)
}

app
