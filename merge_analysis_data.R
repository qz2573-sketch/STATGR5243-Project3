source("utils_logging.R", local = TRUE)
source("analyze_simulation_prep.R", local = TRUE)

read_summary_or_empty <- function(path, data_source) {
  ensure_session_summary_file(path)
  summary_df <- utils::read.csv(path, stringsAsFactors = FALSE)
  normalize_session_summary_frame(summary_df, default_source = data_source)
}

build_combined_session_summary <- function(
  simulated_summary_path = default_session_summary_path("simulated"),
  real_summary_path = default_session_summary_path("real_user"),
  output_path = default_combined_session_summary_path(),
  rebuild_simulated = TRUE
) {
  ensure_legacy_simulated_data_migrated()

  if (isTRUE(rebuild_simulated)) {
    build_session_summary(
      log_path = default_event_log_path("simulated"),
      manifest_path = default_manifest_path(),
      summary_path = simulated_summary_path
    )
  }

  simulated_summary <- read_summary_or_empty(simulated_summary_path, "simulated")
  real_summary <- read_summary_or_empty(real_summary_path, "real_user")

  if (!nrow(real_summary)) {
    real_summary <- session_summary_header()[0, , drop = FALSE]
  }

  if (nrow(real_summary)) {
    real_summary$persona[is.na(real_summary$persona) | !nzchar(real_summary$persona)] <- NA_character_
    real_summary$data_source <- "real_user"
  }

  if (nrow(simulated_summary)) {
    simulated_summary$data_source <- "simulated"
  }

  combined_summary <- normalize_session_summary_frame(
    dplyr::bind_rows(simulated_summary, real_summary),
    default_source = "simulated"
  )

  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  }
  utils::write.csv(combined_summary, output_path, row.names = FALSE)
  invisible(combined_summary)
}

if (sys.nframe() == 0) {
  combined_summary <- build_combined_session_summary()
  counts <- table(combined_summary$data_source)
  simulated_rows <- if ("simulated" %in% names(counts)) counts[["simulated"]] else 0
  real_rows <- if ("real_user" %in% names(counts)) counts[["real_user"]] else 0
  cat("combined_rows=", nrow(combined_summary), "\n", sep = "")
  cat("simulated_rows=", simulated_rows, "\n", sep = "")
  cat("real_user_rows=", real_rows, "\n", sep = "")
}
