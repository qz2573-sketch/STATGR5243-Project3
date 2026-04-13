source("utils_logging.R", local = TRUE)
source("shared_logic.R", local = TRUE)
source("ui_variant_b.R", local = TRUE)

app <- shinyApp(ui = ui_variant_b(), server = shared_server)

if (interactive()) {
  print(app)
}
