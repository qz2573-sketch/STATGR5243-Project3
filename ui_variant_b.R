ui_variant_b <- function() {
  fluidPage(
    theme = bs_theme(version = 5, primary = "#2E69A8"),
    tags$head(
      tags$style(HTML("
        body {
          background: linear-gradient(180deg, #eef6ff 0%, #dcecff 100%);
          color: #12385f;
        }
        .container-fluid {
          padding-left: 18px;
          padding-right: 18px;
          padding-bottom: 28px;
        }
        .top-banner {
          background: #1F4E82;
          color: white;
          padding: 30px 28px 36px 28px;
          border-radius: 0 0 28px 28px;
          box-shadow: 0 10px 28px rgba(31, 78, 130, 0.20);
          margin-bottom: 24px;
        }
        .app-title {
          font-size: 40px;
          font-weight: 800;
          line-height: 1.1;
          margin-bottom: 10px;
        }
        .app-subtitle {
          max-width: 920px;
          line-height: 1.75;
          font-size: 17px;
          opacity: 0.96;
        }
        .hero-card {
          background: linear-gradient(135deg, #5fa7e8 0%, #7cbaf0 55%, #a8d2f7 100%);
          color: white;
          border-radius: 28px;
          padding: 34px 30px;
          box-shadow: 0 14px 30px rgba(83, 154, 220, 0.18);
          margin-bottom: 28px;
        }
        .hero-title {
          font-size: 42px;
          font-weight: 800;
          line-height: 1.15;
          margin-bottom: 14px;
        }
        .hero-text {
          font-size: 17px;
          line-height: 1.8;
          max-width: 920px;
          margin-bottom: 20px;
        }
        .cta-row {
          display: flex;
          gap: 14px;
          flex-wrap: wrap;
        }
        .cta-btn {
          display: inline-block;
          padding: 12px 22px;
          border-radius: 14px;
          font-weight: 700;
          text-decoration: none;
        }
        .cta-primary {
          background: white;
          color: #1F4E82;
          box-shadow: 0 8px 20px rgba(31, 78, 130, 0.16);
        }
        .cta-secondary {
          color: white;
          border: 2px solid rgba(255,255,255,0.45);
          background: rgba(255,255,255,0.08);
        }
        .section-title {
          font-size: 24px;
          font-weight: 800;
          color: #163e68;
          margin-bottom: 16px;
        }
        .feature-card {
          background: linear-gradient(180deg, #ffffff 0%, #f5faff 100%);
          border-radius: 24px;
          padding: 24px 22px;
          box-shadow: 0 10px 24px rgba(23, 67, 114, 0.08);
          border: 1px solid #dbeeff;
          min-height: 220px;
          margin-bottom: 24px;
        }
        .feature-title {
          font-size: 20px;
          font-weight: 800;
          color: #163f69;
          margin-bottom: 10px;
        }
        .feature-text {
          font-size: 15px;
          line-height: 1.7;
          color: #4a6784;
        }
        .panel-card {
          background: #ffffff;
          border-radius: 24px;
          padding: 24px;
          box-shadow: 0 10px 26px rgba(22, 68, 116, 0.09);
          border: 1px solid #e0efff;
          margin-bottom: 24px;
        }
        .panel-title {
          font-size: 21px;
          font-weight: 800;
          color: #123c67;
          margin-bottom: 14px;
        }
        .help-note {
          background: linear-gradient(180deg, #eef8ff 0%, #e6f3ff 100%);
          border-left: 5px solid #4e96dd;
          padding: 14px 16px;
          border-radius: 12px;
          color: #355472;
          margin-top: 10px;
        }
        .metric-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
          gap: 14px;
          margin-bottom: 18px;
        }
        .metric-card {
          background: linear-gradient(180deg, #ffffff 0%, #f7fbff 100%);
          border: 1px solid #dbeeff;
          border-radius: 18px;
          padding: 18px;
          box-shadow: 0 8px 20px rgba(22, 68, 116, 0.06);
        }
        .metric-label {
          font-size: 13px;
          color: #53708e;
          text-transform: uppercase;
          letter-spacing: 0.06em;
          margin-bottom: 6px;
        }
        .metric-value {
          font-size: 26px;
          font-weight: 800;
          color: #123c67;
        }
        .nav-tabs {
          border-bottom: none;
          margin-bottom: 18px;
        }
        .nav-tabs > li > a {
          border-radius: 999px;
          border: none;
          background: rgba(255,255,255,0.72);
          color: #24496f;
          font-weight: 700;
          margin-right: 8px;
        }
        .nav-tabs > li.active > a,
        .nav-tabs > li.active > a:focus,
        .nav-tabs > li.active > a:hover {
          border: none;
          color: white;
          background: linear-gradient(135deg, #2E69A8 0%, #5fa7e8 100%);
          box-shadow: 0 8px 18px rgba(83, 154, 220, 0.25);
        }
        .btn, .btn-primary {
          border-radius: 14px;
          font-weight: 700;
        }
      "))
    ),
    div(
      class = "top-banner",
      div(class = "app-title", "DataPilot B"),
      div(
        class = "app-subtitle",
        "A guided version of the same Shiny workflow for upload, cleaning, feature engineering, and EDA. This variant keeps the backend identical to Variant A while adding onboarding, clearer visual hierarchy, and more polished card-based presentation."
      )
    ),
    div(
      class = "hero-card",
      div(class = "hero-title", "Move from raw data to analysis-ready output in four guided steps"),
      div(
        class = "hero-text",
        "Use a built-in sample or your own file, review the dataset structure, apply transformations, create features, and explore results with interactive plots. The analysis behavior is unchanged; only the interface, guidance, and visual emphasis differ from Variant A."
      ),
      div(
        class = "cta-row",
        tags$a(href = "#workflow-tabs", class = "cta-btn cta-primary", "Jump to workflow"),
        tags$a(href = "#guide-card", class = "cta-btn cta-secondary", "Read the quick guide")
      )
    ),
    div(class = "section-title", "Workflow highlights"),
    fluidRow(
      column(
        4,
        div(
          class = "feature-card",
          div(class = "feature-title", "1. Load data"),
          div(class = "feature-text", "Start with `airquality` or `iris`, or upload CSV, TSV/TXT, Excel, JSON, or RDS data.")
        )
      ),
      column(
        4,
        div(
          class = "feature-card",
          div(class = "feature-title", "2. Clean and transform"),
          div(class = "feature-text", "Standardize names, handle missing values, detect dates, scale numeric features, and manage outliers.")
        )
      ),
      column(
        4,
        div(
          class = "feature-card",
          div(class = "feature-title", "3. Engineer and explore"),
          div(class = "feature-text", "Create derived variables, preview the engineered dataset, download it, and inspect EDA plots and summaries.")
        )
      )
    ),
    div(id = "workflow-tabs"),
    tabsetPanel(
      id = "main_nav_b",
      tabPanel(
        "Guide",
        fluidRow(
          column(
            7,
            div(
              id = "guide-card",
              class = "panel-card",
              div(class = "panel-title", "Quick guide"),
              tags$ol(
                tags$li("Go to Data and choose a built-in dataset or upload a file."),
                tags$li("Review the structure summary before changing any cleaning options."),
                tags$li("Adjust the Cleaning tab and inspect the transformation log."),
                tags$li("Create one or more engineered features if needed."),
                tags$li("Open EDA to filter the resulting dataset and compare plots.")
              ),
              div(class = "help-note", tags$b("Tip: "), "Use the built-in datasets first if you want to compare the two variants without changing the data source.")
            )
          ),
          column(
            5,
            div(
              class = "panel-card",
              div(class = "panel-title", "What stays constant"),
              tags$ul(
                tags$li("Same data upload logic"),
                tags$li("Same cleaning and transformation workflow"),
                tags$li("Same feature engineering behavior"),
                tags$li("Same EDA outputs and backend behavior")
              ),
              div(class = "help-note", tags$b("For the experiment: "), "this version changes wording, onboarding, layout, and visual emphasis only.")
            )
          )
        )
      ),
      tabPanel(
        "Data",
        fluidRow(
          column(
            4,
            div(
              class = "panel-card",
              div(class = "panel-title", "Step 1: Choose a data source"),
              radioButtons("source_type", "Data source", choices = c("Built-in dataset", "Upload file")),
              conditionalPanel(
                condition = "input.source_type === 'Built-in dataset'",
                selectInput("builtin_name", "Choose a sample dataset", choices = names(builtin_datasets))
              ),
              conditionalPanel(
                condition = "input.source_type === 'Upload file'",
                fileInput("upload_file", "Upload dataset", accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx", ".json", ".rds")),
                div(class = "help-note", "Supported formats: CSV, TSV/TXT, Excel, JSON, and RDS.")
              )
            )
          ),
          column(
            8,
            div(
              class = "panel-card",
              div(class = "panel-title", "Dataset overview"),
              div(
                class = "metric-grid",
                div(class = "metric-card", div(class = "metric-label", "Rows"), div(class = "metric-value", textOutput("raw_rows"))),
                div(class = "metric-card", div(class = "metric-label", "Columns"), div(class = "metric-value", textOutput("raw_cols"))),
                div(class = "metric-card", div(class = "metric-label", "Missing Cells"), div(class = "metric-value", textOutput("raw_missing")))
              ),
              h4("Column types"),
              tableOutput("raw_types"),
              h4("Preview"),
              tableOutput("raw_preview")
            )
          )
        )
      ),
      tabPanel(
        "Cleaning",
        fluidRow(
          column(
            4,
            div(
              class = "panel-card",
              div(class = "panel-title", "Step 2: Configure cleaning"),
              checkboxInput("standardize_names", "Standardize column names", TRUE),
              checkboxInput("trim_whitespace", "Trim whitespace in character columns", TRUE),
              checkboxInput("coerce_date_columns", "Auto-detect date-like columns", FALSE),
              checkboxInput("remove_duplicates", "Remove duplicate rows", FALSE),
              selectInput(
                "numeric_missing",
                "Numeric missing values",
                choices = c("None", "Remove rows", "Median imputation", "Mean imputation", "Replace with 0")
              ),
              selectInput(
                "categorical_missing",
                "Categorical missing values",
                choices = c("None", "Remove rows", "Mode imputation", "Replace with 'Missing'")
              ),
              selectInput("scaling_method", "Scaling", choices = c("None", "Z-score", "Min-Max")),
              uiOutput("scaling_columns_ui"),
              selectInput("outlier_method", "Outlier handling", choices = c("None", "Cap with IQR bounds", "Remove rows with outliers")),
              uiOutput("outlier_columns_ui"),
              selectInput("encoding_method", "Categorical encoding", choices = c("None", "Label encode")),
              uiOutput("encoding_columns_ui")
            )
          ),
          column(
            8,
            div(
              class = "panel-card",
              div(class = "panel-title", "Cleaning results"),
              div(
                class = "metric-grid",
                div(class = "metric-card", div(class = "metric-label", "Rows After Cleaning"), div(class = "metric-value", textOutput("clean_rows"))),
                div(class = "metric-card", div(class = "metric-label", "Columns After Cleaning"), div(class = "metric-value", textOutput("clean_cols"))),
                div(class = "metric-card", div(class = "metric-label", "Remaining Missing"), div(class = "metric-value", textOutput("clean_missing")))
              ),
              h4("Transformation log"),
              verbatimTextOutput("clean_log"),
              h4("Preview"),
              tableOutput("clean_preview")
            )
          )
        )
      ),
      tabPanel(
        "Feature Engineering",
        fluidRow(
          column(
            4,
            div(
              class = "panel-card",
              div(class = "panel-title", "Step 3: Add features"),
              selectInput(
                "feature_action",
                "Feature engineering action",
                choices = c(
                  "None",
                  "Log transform",
                  "Square root transform",
                  "Binning",
                  "Interaction term",
                  "Ratio feature",
                  "Date parts",
                  "One-hot encode"
                )
              ),
              uiOutput("feature_controls"),
              textInput("new_feature_name", "New feature name", value = "new_feature"),
              actionButton("add_feature", "Create feature", class = "btn-primary"),
              tags$hr(),
              uiOutput("delete_feature_ui"),
              actionButton("delete_feature", "Remove selected features"),
              div(class = "help-note", "Changing any cleaning option resets engineered features to the latest cleaned dataset.")
            )
          ),
          column(
            8,
            div(
              class = "panel-card",
              div(class = "panel-title", "Engineered dataset"),
              div(
                class = "metric-grid",
                div(class = "metric-card", div(class = "metric-label", "Rows"), div(class = "metric-value", textOutput("engineered_rows"))),
                div(class = "metric-card", div(class = "metric-label", "Columns"), div(class = "metric-value", textOutput("engineered_cols"))),
                div(class = "metric-card", div(class = "metric-label", "Latest Change"), div(class = "metric-value", textOutput("feature_message")))
              ),
              h4("Preview"),
              tableOutput("engineered_preview"),
              downloadButton("download_engineered", "Download engineered dataset")
            )
          )
        )
      ),
      tabPanel(
        "EDA",
        fluidRow(
          column(
            4,
            div(
              class = "panel-card",
              div(class = "panel-title", "Step 4: Explore results"),
              selectInput("filter_column", "Filter column", choices = "None"),
              uiOutput("filter_control"),
              selectInput(
                "plot_type",
                "Plot type",
                choices = c("Histogram", "Scatter plot", "Box plot", "Bar chart", "Correlation heatmap")
              ),
              uiOutput("plot_x_ui"),
              uiOutput("plot_y_ui"),
              uiOutput("plot_color_ui")
            )
          ),
          column(
            8,
            div(
              class = "panel-card",
              div(class = "panel-title", "Interactive EDA plot"),
              plotOutput("eda_plot", height = "600px")
            ),
            div(
              class = "panel-card",
              div(class = "panel-title", "Summary statistics"),
              tableOutput("eda_summary")
            ),
            div(
              class = "panel-card",
              div(class = "panel-title", "Filtered data preview"),
              tableOutput("eda_preview")
            )
          )
        )
      )
    )
  )
}
