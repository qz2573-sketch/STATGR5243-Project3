suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

preferred_dataset <- file.path("data", "session_summary(3).csv")
fallback_dataset <- file.path("data", "session_summary.csv")
output_dir <- file.path("analysis_outputs")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

dataset_path <- if (file.exists(preferred_dataset)) preferred_dataset else fallback_dataset

if (!file.exists(dataset_path)) {
  stop("No session summary dataset was found.")
}

session_summary <- utils::read.csv(dataset_path, stringsAsFactors = FALSE)
full_data <- session_summary %>%
  filter(run_label == "full")

if (!nrow(full_data)) {
  stop("No rows found for run_label == 'full'.")
}

binary_test <- function(data, metric) {
  tab <- table(data$variant, data[[metric]])
  test_obj <- prop.test(
    x = c(sum(data$variant == "A" & data[[metric]]), sum(data$variant == "B" & data[[metric]])),
    n = c(sum(data$variant == "A"), sum(data$variant == "B")),
    correct = FALSE
  )
  tibble(
    metric = metric,
    test_name = "Two-sample proportion test",
    variant_a = mean(data[[metric]][data$variant == "A"]),
    variant_b = mean(data[[metric]][data$variant == "B"]),
    difference_b_minus_a = mean(data[[metric]][data$variant == "B"]) - mean(data[[metric]][data$variant == "A"]),
    p_value = unname(test_obj$p.value),
    statistic = unname(test_obj$statistic)
  )
}

continuous_test <- function(data, metric) {
  test_obj <- t.test(data[[metric]] ~ data$variant, var.equal = FALSE)
  tibble(
    metric = metric,
    test_name = "Welch t-test",
    variant_a = mean(data[[metric]][data$variant == "A"]),
    variant_b = mean(data[[metric]][data$variant == "B"]),
    difference_b_minus_a = mean(data[[metric]][data$variant == "B"]) - mean(data[[metric]][data$variant == "A"]),
    p_value = unname(test_obj$p.value),
    statistic = unname(test_obj$statistic)
  )
}

summary_table <- bind_rows(
  binary_test(full_data, "first_key_action_taken"),
  binary_test(full_data, "task_completed"),
  continuous_test(full_data, "session_duration"),
  continuous_test(full_data, "num_events")
) %>%
  mutate(across(c(variant_a, variant_b, difference_b_minus_a, p_value, statistic), ~ round(., 4)))

persona_summary <- full_data %>%
  group_by(persona, variant) %>%
  summarise(
    n = n(),
    first_key_action_taken = mean(first_key_action_taken),
    task_completed = mean(task_completed),
    session_duration = mean(session_duration),
    num_events = mean(num_events),
    .groups = "drop"
  ) %>%
  mutate(across(c(first_key_action_taken, task_completed, session_duration, num_events), ~ round(., 4)))

overall_rates <- full_data %>%
  group_by(variant) %>%
  summarise(
    first_key_action_taken = mean(first_key_action_taken),
    task_completed = mean(task_completed),
    session_duration = mean(session_duration),
    num_events = mean(num_events),
    .groups = "drop"
  )

plot_binary_metric <- function(data, metric, y_label, file_name) {
  plot_data <- data %>%
    group_by(variant) %>%
    summarise(value = mean(.data[[metric]]), .groups = "drop")

  p <- ggplot(plot_data, aes(x = variant, y = value, fill = variant)) +
    geom_col(width = 0.6, show.legend = FALSE) +
    geom_text(aes(label = sprintf("%.2f", value)), vjust = -0.5) +
    scale_y_continuous(limits = c(0, 1)) +
    labs(x = "Variant", y = y_label) +
    theme_minimal(base_size = 12)

  ggplot2::ggsave(file.path(output_dir, file_name), plot = p, width = 6, height = 4, dpi = 300)
}

plot_continuous_metric <- function(data, metric, y_label, file_name) {
  p <- ggplot(data, aes(x = variant, y = .data[[metric]], fill = variant)) +
    geom_boxplot(alpha = 0.7, show.legend = FALSE) +
    geom_jitter(width = 0.15, alpha = 0.25, size = 1.2, show.legend = FALSE) +
    labs(x = "Variant", y = y_label) +
    theme_minimal(base_size = 12)

  ggplot2::ggsave(file.path(output_dir, file_name), plot = p, width = 6, height = 4, dpi = 300)
}

plot_binary_metric(full_data, "first_key_action_taken", "First key action rate", "first_key_action_taken_by_variant.png")
plot_binary_metric(full_data, "task_completed", "Task completion rate", "task_completed_by_variant.png")
plot_continuous_metric(full_data, "session_duration", "Session duration", "session_duration_by_variant.png")
plot_continuous_metric(full_data, "num_events", "Number of events", "num_events_by_variant.png")

results_text <- paste(
  "## Results",
  "",
  sprintf(
    "Using the full simulated run (%d sessions per variant), Variant B showed a higher first-key-action rate than Variant A (%.2f vs %.2f; p = %.4f).",
    sum(full_data$variant == "A"),
    overall_rates$first_key_action_taken[overall_rates$variant == "B"],
    overall_rates$first_key_action_taken[overall_rates$variant == "A"],
    summary_table$p_value[summary_table$metric == "first_key_action_taken"]
  ),
  sprintf(
    "Variant B also showed a higher task completion rate (%.2f vs %.2f; p = %.4f).",
    overall_rates$task_completed[overall_rates$variant == "B"],
    overall_rates$task_completed[overall_rates$variant == "A"],
    summary_table$p_value[summary_table$metric == "task_completed"]
  ),
  sprintf(
    "For continuous outcomes, Variant B produced a slightly longer average session duration (%.2f vs %.2f; Welch t-test p = %.4f) and a higher average number of events (%.2f vs %.2f; Welch t-test p = %.4f).",
    overall_rates$session_duration[overall_rates$variant == "B"],
    overall_rates$session_duration[overall_rates$variant == "A"],
    summary_table$p_value[summary_table$metric == "session_duration"],
    overall_rates$num_events[overall_rates$variant == "B"],
    overall_rates$num_events[overall_rates$variant == "A"],
    summary_table$p_value[summary_table$metric == "num_events"]
  ),
  "",
  "## Interpretation",
  "",
  "Within this simulated A/B environment, the guided and visually enhanced interface was associated with modestly stronger engagement than the utility-first interface. The pattern is directionally consistent with the study hypothesis, but the results should be interpreted as behavior generated under calibrated simulation assumptions rather than evidence from real users.",
  "",
  "## Limitations",
  "",
  "This analysis is based entirely on simulated sessions rather than observed user behavior. The findings therefore depend on the chosen persona probabilities, stopping rules, and interaction model. Although the simulation preserves randomness and produces internally consistent behavioral traces, it cannot substitute for a real experiment with human participants.",
  sep = "\n"
)

utils::write.csv(summary_table, file.path(output_dir, "ab_test_summary_table.csv"), row.names = FALSE)
utils::write.csv(persona_summary, file.path(output_dir, "ab_test_persona_breakdown.csv"), row.names = FALSE)
writeLines(results_text, file.path(output_dir, "ab_test_results.md"))

cat("dataset_used=", dataset_path, "\n", sep = "")
cat("full_rows=", nrow(full_data), "\n", sep = "")
print(summary_table)
print(persona_summary)
