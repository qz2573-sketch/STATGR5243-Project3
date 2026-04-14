`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

parse_deploy_args <- function(args) {
  config <- list(
    app_name = Sys.getenv("SHINYAPPS_APP_NAME", unset = "abtest-launcher"),
    account = Sys.getenv("SHINYAPPS_ACCOUNT", unset = ""),
    server = "shinyapps.io"
  )

  for (arg in args) {
    if (grepl("^--app-name=", arg)) {
      config$app_name <- sub("^--app-name=", "", arg)
    } else if (grepl("^--account=", arg)) {
      config$account <- sub("^--account=", "", arg)
    } else if (grepl("^--server=", arg)) {
      config$server <- sub("^--server=", "", arg)
    }
  }

  config
}

if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("The 'rsconnect' package is required. Install it with install.packages('rsconnect').")
}

config <- parse_deploy_args(commandArgs(trailingOnly = TRUE))

if (!nzchar(config$account)) {
  stop("Set SHINYAPPS_ACCOUNT or pass --account=<account> before deploying.")
}

result <- rsconnect::deployApp(
  appDir = getwd(),
  appPrimaryDoc = "app.R",
  appName = config$app_name,
  account = config$account,
  server = config$server,
  launch.browser = FALSE,
  forceUpdate = TRUE
)

app_url <- if (is.list(result) && !is.null(result$url)) {
  result$url
} else {
  sprintf("https://%s.shinyapps.io/%s/", config$account, config$app_name)
}
cat("deployed_url=", app_url, "\n", sep = "")
