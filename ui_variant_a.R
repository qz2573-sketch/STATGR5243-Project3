ui_variant_a <- function() {
  page_navbar(
    title = "DataPilot A",
    id = "main_nav_a",
    theme = bs_theme(
      version = 5,
      bootswatch = "flatly",
      primary = "#1b4965",
      secondary = "#5c677d"
    ),
    nav_panel(
      "Guide",
      layout_column_wrap(
        width = 1 / 2,
        card(
          full_screen = TRUE,
          card_header("What this app does"),
          p("Upload a dataset or choose a built-in example, then run the same workflow through cleaning, feature engineering, and EDA."),
          tags$ol(
            tags$li("Start on the Data tab to load a sample dataset or upload your own file."),
            tags$li("Use Cleaning to standardize names, handle missing values, scale features, and manage outliers."),
            tags$li("Use Feature Engineering to create transformed, binned, date-derived, interaction, ratio, or one-hot encoded variables."),
            tags$li("Use EDA to filter the engineered dataset and inspect plots, summaries, and previews.")
          )
        ),
        card(
          card_header("Supported inputs"),
          tags$ul(
            tags$li("Built-in datasets: airquality, iris"),
            tags$li("Upload formats: CSV, TSV/TXT, Excel, JSON, RDS")
          ),
          p("Variant A keeps the interface compact and utility-first so the full workflow stays easy to scan.")
        ),
        card(
          card_header("Workflow notes"),
          tags$ul(
            tags$li("Later tabs update from earlier steps."),
            tags$li("Changing cleaning settings resets engineered features."),
            tags$li("Both A and B variants use the same backend behavior and outputs.")
          )
        ),
        card(
          card_header("Quick start"),
          p("To test immediately, choose a built-in dataset on the Data tab and move through each tab in order.")
        )
      )
    ),
    nav_panel(
      "Data",
      layout_sidebar(
        sidebar = sidebar(
          width = 320,
          radioButtons("source_type", "Data source", choices = c("Built-in dataset", "Upload file")),
          conditionalPanel(
            condition = "input.source_type === 'Built-in dataset'",
            selectInput("builtin_name", "Choose a sample dataset", choices = names(builtin_datasets))
          ),
          conditionalPanel(
            condition = "input.source_type === 'Upload file'",
            fileInput("upload_file", "Upload dataset", accept = c(".csv", ".tsv", ".txt", ".xls", ".xlsx", ".json", ".rds")),
            helpText("Supported formats: CSV, TSV/TXT, Excel, JSON, and RDS.")
          )
        ),
        card(
          full_screen = TRUE,
          card_header("Dataset Overview"),
          layout_column_wrap(
            width = 1 / 3,
            value_box(title = "Rows", value = textOutput("raw_rows")),
            value_box(title = "Columns", value = textOutput("raw_cols")),
            value_box(title = "Missing Cells", value = textOutput("raw_missing"))
          ),
          h5("Column types"),
          tableOutput("raw_types"),
          h5("Preview"),
          tableOutput("raw_preview")
        )
      )
    ),
    nav_panel(
      "Cleaning",
      layout_sidebar(
        sidebar = sidebar(
          width = 340,
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
        ),
        card(
          full_screen = TRUE,
          card_header("Cleaning Results"),
          layout_column_wrap(
            width = 1 / 3,
            value_box(title = "Rows After Cleaning", value = textOutput("clean_rows")),
            value_box(title = "Columns After Cleaning", value = textOutput("clean_cols")),
            value_box(title = "Remaining Missing Cells", value = textOutput("clean_missing"))
          ),
          h5("Transformation log"),
          verbatimTextOutput("clean_log"),
          h5("Preview"),
          tableOutput("clean_preview")
        )
      )
    ),
    nav_panel(
      "Feature Engineering",
      layout_sidebar(
        sidebar = sidebar(
          width = 340,
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
          actionButton("add_feature", "Add feature", class = "btn-primary"),
          uiOutput("delete_feature_ui"),
          actionButton("delete_feature", "Delete selected features"),
          helpText("Changing cleaning settings resets the engineered dataset to the latest cleaned version.")
        ),
        card(
          full_screen = TRUE,
          card_header("Engineered Dataset"),
          layout_column_wrap(
            width = 1 / 3,
            value_box(title = "Rows", value = textOutput("engineered_rows")),
            value_box(title = "Columns", value = textOutput("engineered_cols")),
            value_box(title = "Most Recent Change", value = textOutput("feature_message"))
          ),
          h5("Preview"),
          tableOutput("engineered_preview"),
          downloadButton("download_engineered", "Download engineered dataset")
        )
      )
    ),
    nav_panel(
      "EDA",
      layout_sidebar(
        sidebar = sidebar(
          width = 320,
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
        ),
        layout_column_wrap(
          width = 1,
          card(
            full_screen = TRUE,
            card_header("Interactive EDA Plot"),
            div(style = "min-height: 620px; padding-bottom: 1rem;", plotOutput("eda_plot", height = "600px"))
          ),
          card(
            full_screen = TRUE,
            card_header("Summary Statistics"),
            tableOutput("eda_summary")
          ),
          card(
            full_screen = TRUE,
            card_header("Filtered Data Preview"),
            tableOutput("eda_preview")
          )
        )
      )
    )
  )
}
