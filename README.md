# STATGR 5243 Project 3: DataPilot A/B Test

This repository contains Team 24's Project 3 submission for STATGR 5243. The project designs, implements, and analyzes an A/B test using an R Shiny data analysis application called **DataPilot**.

The main question is:

> Does a guided, visually enhanced user interface increase user engagement and task completion compared with a simpler utility-first interface, when the underlying app functionality remains unchanged?

## Quick Links

- Public deployed app: [https://statgr5243project.shinyapps.io/abtest-launcher/](https://statgr5243project.shinyapps.io/abtest-launcher/)
- Force Variant A: [https://statgr5243project.shinyapps.io/abtest-launcher/?variant=A](https://statgr5243project.shinyapps.io/abtest-launcher/?variant=A)
- Force Variant B: [https://statgr5243project.shinyapps.io/abtest-launcher/?variant=B](https://statgr5243project.shinyapps.io/abtest-launcher/?variant=B)
- Main analysis output: `analysis_outputs/ab_test_results.md`
- Summary results table: `analysis_outputs/ab_test_summary_table.csv`
- Main analysis script: `analyze_ab_results.R`

## Project Summary

DataPilot is a Shiny application that helps users complete a small data-analysis workflow:

- load a built-in dataset or upload a file
- inspect dataset dimensions, missing values, column types, and preview rows
- apply cleaning and transformation options
- create engineered features
- generate exploratory plots and summary statistics
- download the engineered dataset

The A/B test compares two versions of the same application:

- **Variant A, control**: a compact, utility-first interface.
- **Variant B, treatment**: a guided and visually enhanced interface with more onboarding, clearer visual hierarchy, and step-based framing.

The backend workflow is shared across both variants through `shared_logic.R`. This means that the treatment difference is focused on interface design, guidance, layout, and presentation rather than differences in data-processing functionality.

## Experimental Design

The experiment uses a two-arm A/B testing design.

| Component | Description |
| --- | --- |
| Control group | Variant A, the simpler utility-first DataPilot interface |
| Treatment group | Variant B, the guided and visually enhanced DataPilot interface |
| Assignment mechanism | New sessions are assigned to A or B inside the Shiny launcher app |
| Debug override | `?variant=A` and `?variant=B` can be used to force a variant for testing |
| Primary outcome | `first_key_action_taken` |
| Secondary outcomes | `task_completed`, `session_duration`, `num_events` |
| Main inferential dataset | Full simulated run with 100 sessions per variant |

The primary metric, `first_key_action_taken`, measures whether a user takes an initial meaningful action, such as choosing a sample dataset or uploading data. This metric is used as the main engagement outcome because it captures whether the interface encourages users to begin using the app.

The secondary metrics measure deeper engagement:

- `task_completed`: whether the session reached the intended workflow completion point
- `session_duration`: how long the session lasted
- `num_events`: how many tracked interaction events were recorded

## Repository Map

### Shiny Application Files

| File | Purpose |
| --- | --- |
| `app.R` | Deployable public entry point for shinyapps.io |
| `app_abtest.R` | Main A/B launcher with random assignment and URL override support |
| `app_variant_a.R` | Standalone entry point for Variant A |
| `app_variant_b.R` | Standalone entry point for Variant B |
| `ui_variant_a.R` | UI definition for Variant A |
| `ui_variant_b.R` | UI definition for Variant B |
| `shared_logic.R` | Shared backend app logic for data loading, cleaning, feature engineering, and EDA |
| `utils_logging.R` | Event logging, session metadata, GA4 helpers, and data-path utilities |

### Simulation, Data Preparation, and Analysis Files

| File | Purpose |
| --- | --- |
| `simulate_sessions.R` | Runs simulated user sessions through the Shiny app with `shinytest2` |
| `analyze_simulation_prep.R` | Converts raw simulated event logs into session-level summaries |
| `merge_analysis_data.R` | Combines simulated and real-user session summaries into one analysis-ready file |
| `prepare_ga4_export.R` | Converts exported GA4 event data into the same session-level schema |
| `analyze_ab_results.R` | Runs the final A/B analysis and writes tables, plots, and report text |
| `deploy_shinyapps.R` | Deploys the public app to shinyapps.io |
| `real_data_session.Rmd` | Supplementary notebook for real-user/bridge data exploration |

### Data Directories

| Path | Description |
| --- | --- |
| `data/` | Legacy local simulated files from the earlier project structure |
| `data/simulated/` | Canonical simulated event logs, session summaries, and simulation manifest |
| `data/real/` | Real-user event/session files from deployed or GA4-based collection |
| `data/analysis/` | Combined analysis-ready session-level dataset |
| `analysis_outputs/` | Final tables, plots, and report-ready text outputs |

## Important Data Files

| File | Description |
| --- | --- |
| `data/simulated/event_log_simulated.csv` | Raw event-level log from simulated sessions |
| `data/simulated/session_summary_simulated.csv` | Simulated session-level summary dataset |
| `data/simulated/simulation_manifest_simulated.csv` | Session manifest with variant, persona, run label, and planned dataset |
| `data/real/event_log_real.csv` | Real-user event log file |
| `data/real/session_summary_real.csv` | Real-user session summary file |
| `data/analysis/session_summary_combined.csv` | Combined session-level dataset created by `merge_analysis_data.R` |
| `analysis_outputs/session_summary_combined.csv` | Supplementary combined output used for report-facing analysis artifacts |
| `analysis_outputs/ab_test_summary_table.csv` | Final statistical test summary table |
| `analysis_outputs/ab_test_persona_breakdown.csv` | Exploratory results by simulated persona and variant |
| `analysis_outputs/ab_test_results.md` | Short report-ready results and interpretation text |

## Analysis Outputs

The main analysis script produces the following output files in `analysis_outputs/`:

- `ab_test_summary_table.csv`
- `ab_test_persona_breakdown.csv`
- `ab_test_results.md`
- `first_key_action_taken_by_variant.png`
- `task_completed_by_variant.png`
- `session_duration_by_variant.png`
- `num_events_by_variant.png`

These files are intended to support the final written report.

## Required R Packages

Install the required packages once before running the app or analysis:

```r
install.packages(c(
  "shiny",
  "bslib",
  "ggplot2",
  "dplyr",
  "readxl",
  "jsonlite",
  "shinytest2",
  "rsconnect"
))
```

## How To Run The App Locally

The commands below use `Rscript`. On Windows, replace `Rscript` with the full Rscript path if needed, for example:

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe"
```

### Run The Main A/B Launcher

```bash
Rscript -e "shiny::runApp('app_abtest.R', port = 3840, launch.browser = TRUE)"
```

Open:

- <http://127.0.0.1:3840>

Manual override URLs:

- <http://127.0.0.1:3840/?variant=A>
- <http://127.0.0.1:3840/?variant=B>

### Run Variant A Directly

```bash
Rscript -e "shiny::runApp('app_variant_a.R', port = 3838, launch.browser = TRUE)"
```

Open:

- <http://127.0.0.1:3838>

### Run Variant B Directly

```bash
Rscript -e "shiny::runApp('app_variant_b.R', port = 3839, launch.browser = TRUE)"
```

Open:

- <http://127.0.0.1:3839>

## How The A/B Test Works In The Code

The single public launcher is implemented in `app_abtest.R`.

At the beginning of each session:

- the app checks whether the URL contains a variant override
- if the URL contains `?variant=A` or `?variant=B`, that variant is assigned
- otherwise, the app randomly samples Variant A or Variant B
- the assigned variant is stored in `session$userData$variant`
- the session receives a generated `session_id`
- the selected UI is rendered through `uiOutput("assigned_ui")`

The backend behavior then comes from `shared_logic.R`, so Variant A and Variant B use the same data-processing and plotting logic.

## Logging And Metrics

The logging system records event-level data during each session. Important tracked events include:

- `session_start`
- `landing_view`
- `tab_view`
- `sample_data_clicked`
- `upload_clicked`
- `first_key_action`
- `cleaning_applied`
- `feature_engineering_applied`
- `eda_generated`
- `task_completed`
- `session_end`

Each event row contains:

- `session_id`
- `variant`
- `run_label`
- `timestamp`
- `event_name`
- `event_value`
- `tab_name`
- `data_source`

The session-level analysis file uses these fields:

- `session_id`
- `variant`
- `persona`
- `run_label`
- `data_source`
- `first_key_action_taken`
- `task_completed`
- `session_duration`
- `num_events`

## How To Reproduce The Simulated Analysis

The final simulated analysis is based on a full run with 100 sessions per variant.

### 1. Run A Small Pilot Simulation

This is useful for checking that the app and logging pipeline work:

```bash
Rscript simulate_sessions.R --pilot --reset
```

### 2. Run The Full Simulation

```bash
Rscript simulate_sessions.R --full
```

### 3. Rebuild The Simulated Session Summary

```bash
Rscript analyze_simulation_prep.R
```

### 4. Build The Combined Analysis Dataset

```bash
Rscript merge_analysis_data.R
```

### 5. Run The Final A/B Analysis

```bash
Rscript analyze_ab_results.R
```

The final analysis script:

- loads the combined session summary dataset
- filters to `data_source == "simulated"`
- filters to `run_label == "full"`
- compares Variant A and Variant B on the four defined outcome metrics
- uses two-sample proportion tests for binary outcomes
- uses Welch t-tests for continuous outcomes
- writes result tables, figures, and short report text to `analysis_outputs/`

## Main Simulated Results

The main simulated full-run results are stored in `analysis_outputs/ab_test_summary_table.csv`.

| Metric | Test | Variant A | Variant B | Difference B - A | p-value |
| --- | --- | ---: | ---: | ---: | ---: |
| `first_key_action_taken` | Two-sample proportion test | 0.61 | 0.75 | 0.14 | 0.0338 |
| `task_completed` | Two-sample proportion test | 0.31 | 0.41 | 0.10 | 0.1407 |
| `session_duration` | Welch t-test | 3.4609 | 3.5236 | 0.0627 | 0.7967 |
| `num_events` | Welch t-test | 6.59 | 7.49 | 0.90 | 0.0764 |

In the simulated full run, Variant B has a higher value than Variant A for all four metrics. The first key action rate is statistically significant at the 5% level, while the other metrics are directionally positive but not statistically significant at the 5% level.

## Google Analytics And Real-User Data

The deployed app can also send engagement events to Google Analytics 4 when a GA4 measurement ID is configured. The current code defaults to the measurement ID defined in `utils_logging.R`, and it can also be overridden locally with the `GA4_MEASUREMENT_ID` environment variable.

Tracked GA4 events include:

- `session_start`
- `landing_view`
- `experiment_assignment`
- `tab_view`
- `sample_data_clicked`
- `upload_clicked`
- `first_key_action`
- `cleaning_applied`
- `feature_engineering_applied`
- `eda_generated`
- `task_completed`
- `session_summary`
- `session_end`

Each GA4 event may include app-side parameters such as:

- `session_id`
- `variant`
- `persona`
- `run_label`
- `data_source`
- `tab_name`
- `event_value`
- `event_count`
- `session_duration`
- `num_events`
- `first_key_action_taken`
- `task_completed`

To convert an exported GA4 event file into the same session-level format used by the simulation pipeline, run:

```bash
Rscript prepare_ga4_export.R --input=data/real/ga4_events_export.csv --output=data/real/session_summary_real_ga4.csv
```

The resulting file uses the same columns as the combined analysis dataset, which makes simulated and real-user rows easier to compare or merge.

## Deployment To shinyapps.io

The deployed app uses `app.R` as the public entry point. It keeps one public URL and performs variant assignment inside the app.

### One-Time Account Setup

In an interactive R session:

```r
rsconnect::setAccountInfo(
  name = "<your-account-name>",
  token = "<your-token>",
  secret = "<your-secret>"
)
```

### Deploy The Public A/B App

```bash
Rscript deploy_shinyapps.R --app-name=abtest-launcher
```

On Windows PowerShell, if the deployment account needs to be set first:

```powershell
$env:SHINYAPPS_ACCOUNT = "<your-account-name>"
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" deploy_shinyapps.R --app-name=abtest-launcher
```

The deployed app:

- exposes one public URL
- randomly assigns each new session to Variant A or Variant B
- supports `?variant=A` and `?variant=B` for debugging
- logs deployed traffic to `data/real/`
- sends additional GA4 events when configured

## Suggested Reading Order For Evaluation

For a quick review of the project, we suggest reading files in this order:

1. `5243 Project 3 Team 24.docx`
2. `README.md`
3. `app_abtest.R`
4. `ui_variant_a.R` and `ui_variant_b.R`
5. `shared_logic.R`
6. `simulate_sessions.R`
7. `analyze_ab_results.R`
8. `analysis_outputs/ab_test_summary_table.csv`
9. `analysis_outputs/ab_test_results.md`

This order follows the project logic: report, experiment setup, app implementation, simulation process, and statistical results.

## Notes On Interpretation

This repository supports both simulated and real-user traffic. The main reproducible analysis output generated by `analyze_ab_results.R` uses the simulated full run by default. Real-user rows are kept separate through the `data_source` field so that they can be analyzed independently, compared side by side, or pooled in a later supplementary analysis.

The simulated sessions are useful because they create a controlled and balanced experimental setting. However, simulated sessions should be interpreted as controlled evidence about the designed interaction process, not as a complete substitute for observed human behavior.
