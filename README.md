# R Shiny A/B Testing Project

## Project Overview

This project implements a simulated A/B testing workflow for an R Shiny data analysis application. The app supports the same core analysis workflow in both variants:

- data upload
- data cleaning and transformation
- feature engineering
- exploratory data analysis
- engineered dataset download

The experiment compares two interface treatments:

- **Variant A**: a simple, utility-first interface
- **Variant B**: a guided, visually enhanced interface

The backend workflow is shared across both variants. Only the presentation, onboarding, and interaction framing differ.

## What This Experiment Includes

This repository contains four connected layers:

1. **Application layer**
   - two runnable Shiny interfaces built on the same analysis workflow
2. **A/B testing layer**
   - a single launcher app that randomly assigns each session to Variant A or Variant B
   - optional URL override support using `?variant=A` or `?variant=B`
   - a deployable `app.R` entry point for one public URL
3. **Logging layer**
   - separate simulated and real-user logging with a `data_source` label
4. **Simulation and analysis layer**
   - simulated user sessions driven through the real app
   - session-level aggregation
   - combined analysis-ready datasets for simulated and real-user traffic
   - formal A/B analysis, plots, and report-ready outputs

## Repository Structure

### Core Shiny application files

- `app.R`
  - deployable public entry point for shinyapps.io
- `app_variant_a.R`
  - standalone entry point for Variant A
- `app_variant_b.R`
  - standalone entry point for Variant B
- `app_abtest.R`
  - main A/B launcher app with session-level random assignment and optional URL override
- `shared_logic.R`
  - shared server-side workflow for data loading, cleaning, feature engineering, and EDA
- `ui_variant_a.R`
  - UI definition for Variant A
- `ui_variant_b.R`
  - UI definition for Variant B
- `utils_logging.R`
  - event logging helpers, session metadata helpers, path management, and data layout migration utilities

### Simulation and preprocessing files

- `simulate_sessions.R`
  - runs simulated user sessions against the real Shiny app with `shinytest2`
- `analyze_simulation_prep.R`
  - converts simulated raw event logs into session-level summary rows
- `merge_analysis_data.R`
  - combines simulated and real-user session summaries into one analysis-ready dataset
- `prepare_ga4_export.R`
  - converts exported GA4 `session_summary` events into the same session-level schema used by the simulation pipeline
- `deploy_shinyapps.R`
  - deploys the public `app.R` entry point to shinyapps.io

### Final analysis files

- `analyze_ab_results.R`
  - performs the final A/B analysis using the session-level dataset

### Data files

- `data/event_log.csv`
  - legacy simulated event log preserved from the original local-only project
- `data/session_summary.csv`
  - legacy simulated session summary preserved from the original local-only project
- `data/simulation_manifest.csv`
  - legacy simulated manifest preserved from the original local-only project
- `data/simulated/event_log_simulated.csv`
  - canonical simulated event log used going forward
- `data/simulated/session_summary_simulated.csv`
  - canonical simulated session-level dataset
- `data/simulated/simulation_manifest_simulated.csv`
  - canonical simulated manifest with persona metadata
- `data/real/event_log_real.csv`
  - deployed real-user event log
- `data/real/session_summary_real.csv`
  - deployed real-user session summary dataset
- `data/analysis/session_summary_combined.csv`
  - merge-ready combined dataset retaining the `data_source` label

### Analysis outputs

- `analysis_outputs/ab_test_summary_table.csv`
  - summary table of outcome metrics and p-values
- `analysis_outputs/ab_test_persona_breakdown.csv`
  - exploratory breakdown by persona and variant
- `analysis_outputs/ab_test_results.md`
  - concise report-ready Results, Interpretation, and Limitations text
- `analysis_outputs/first_key_action_taken_by_variant.png`
- `analysis_outputs/task_completed_by_variant.png`
- `analysis_outputs/session_duration_by_variant.png`
- `analysis_outputs/num_events_by_variant.png`

## Required R Packages

Install the required packages once if needed:

```r
install.packages(c("shiny", "bslib", "ggplot2", "dplyr", "readxl", "jsonlite", "shinytest2", "rsconnect"))
```

## How to Run the App Locally

### Run the main A/B launcher

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "shiny::runApp('app_abtest.R', port = 3840, launch.browser = TRUE)"
```

Open:

- <http://127.0.0.1:3840>

Manual override URLs:

- <http://127.0.0.1:3840/?variant=A>
- <http://127.0.0.1:3840/?variant=B>

### Run Variant A directly

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "shiny::runApp('app_variant_a.R', port = 3838, launch.browser = TRUE)"
```

Open:

- <http://127.0.0.1:3838>

### Run Variant B directly

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "shiny::runApp('app_variant_b.R', port = 3839, launch.browser = TRUE)"
```

Open:

- <http://127.0.0.1:3839>

## How the A/B Experiment Works

- each new session is assigned to Variant A or Variant B
- the assignment is stored in `session$userData$variant`
- each session receives a `session_id` and `start_time`
- simulated events are written to `data/simulated/event_log_simulated.csv`
- deployed real-user events are written to `data/real/event_log_real.csv`
- each event row includes `data_source` so simulated and real traffic stay distinguishable
- URL overrides make it possible to force a specific variant for debugging or demonstration

The logging pipeline records key events such as:

- `session_start`
- `landing_view`
- `sample_data_clicked`
- `upload_clicked`
- `first_key_action`
- `cleaning_applied`
- `feature_engineering_applied`
- `eda_generated`
- `task_completed`
- `session_end`

Each event row includes:

- `session_id`
- `variant`
- `run_label`
- `timestamp`
- `event_name`
- `event_value`
- `tab_name`
- `data_source`

## How to Run the Simulation Locally

### Pilot simulation

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" simulate_sessions.R --pilot --reset
```

### Full simulation

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" simulate_sessions.R --full
```

### Rebuild the session summary dataset

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" analyze_simulation_prep.R
```

### Build the combined analysis-ready dataset

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" merge_analysis_data.R
```

## How to Run the Final Analysis

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" analyze_ab_results.R
```

The final analysis script:

- loads the combined session summary dataset
- filters to `data_source == "simulated"` for the original simulation-based analysis
- filters to `run_label == "full"`
- compares Variant A and Variant B on:
  - `first_key_action_taken`
  - `task_completed`
  - `session_duration`
  - `num_events`
- uses:
  - two-sample proportion tests for binary outcomes
  - Welch t-tests for continuous outcomes
- generates tables, figures, and report-ready text files in `analysis_outputs/`

## Notes on Interpretation

This project now supports both simulated and real-user traffic. The existing report outputs are still based on the simulated `full` run by default. Real-user rows remain separate through `data_source = "real_user"` and can be analyzed independently, compared side by side, or pooled later through `data/analysis/session_summary_combined.csv`.

## Deployment To shinyapps.io

The deployable public app is `app.R`. It keeps a single public entry URL and performs variant assignment inside the app at session start.

### One-time account setup

In an interactive R session, configure your shinyapps.io account once:

```r
rsconnect::setAccountInfo(
  name = "<your-account-name>",
  token = "<your-token>",
  secret = "<your-secret>"
)
```

### Deploy the public A/B app

```powershell
$env:SHINYAPPS_ACCOUNT = "<your-account-name>"
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" deploy_shinyapps.R --app-name=abtest-launcher
```

The deployed app:

- exposes one public URL
- randomly assigns each new session to Variant A or Variant B
- still supports `?variant=A` or `?variant=B` for debugging
- logs deployed traffic to `data/real/`
- sends additional GA4 events when `GA4_MEASUREMENT_ID` is set during deployment

## Google Analytics (GA4)

The app can send additional engagement events to Google Analytics 4 when a GA4 measurement ID is configured. This project currently defaults to `G-5XYRDJLPHH`, and local overrides can still be provided through the `GA4_MEASUREMENT_ID` environment variable.

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

Each GA4 event also carries app-side parameters when available:

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

If you want these fields to appear in standard GA4 reports, create matching custom dimensions in the GA4 property.

Recommended custom dimensions for A/B analysis alignment:

- `variant`
- `tab_name`
- `run_label`
- `data_source`
- `persona`
- `assignment_mode`
- `virtual_page`

Recommended custom metrics or exported event parameters:

- `session_duration`
- `num_events`
- `event_count`
- `first_key_action_taken`
- `task_completed`

To align GA4 exports with the simulation-ready schema, export GA4 events including `session_summary` and run:

```powershell
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" prepare_ga4_export.R --input=data/real/ga4_events_export.csv --output=data/real/session_summary_real_ga4.csv
```

The resulting `session_summary_real_ga4.csv` uses the same columns as the local combined analysis pipeline:

- `session_id`
- `variant`
- `persona`
- `run_label`
- `data_source`
- `first_key_action_taken`
- `task_completed`
- `session_duration`
- `num_events`

## Storage Strategy

- simulated legacy files are preserved in `data/`
- canonical simulated outputs live in `data/simulated/`
- canonical deployed real-user outputs live in `data/real/`
- merge-ready analysis outputs live in `data/analysis/`

## Merge-Ready Analysis Format

`merge_analysis_data.R` produces one combined session-level dataset with:

- `session_id`
- `variant`
- `persona` (`NA` for real users)
- `run_label`
- `data_source`
- `first_key_action_taken`
- `task_completed`
- `session_duration`
- `num_events`
