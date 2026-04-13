source("utils_logging.R", local = TRUE)
source("shared_logic.R", local = TRUE)
source("ui_variant_a.R", local = TRUE)

app <- shinyApp(ui = ui_variant_a(), server = shared_server)

if (interactive()) {
  print(app)
}
