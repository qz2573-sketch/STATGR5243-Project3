suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(ggplot2)
  library(dplyr)
  library(readxl)
  library(jsonlite)
})

builtin_datasets <- list(
  "airquality" = datasets::airquality,
  "iris" = datasets::iris
)

safe_names <- function(x) {
  x <- trimws(x)
  x <- gsub("[^A-Za-z0-9_]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  make.names(x, unique = TRUE)
}

mode_value <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (!length(x)) {
    return(NA)
  }
  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[1]
}

min_max_scale <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (!all(is.finite(rng)) || diff(rng) == 0) {
    return(rep(0, length(x)))
  }
  (x - rng[1]) / diff(rng)
}

cap_outliers <- function(x) {
  q1 <- stats::quantile(x, 0.25, na.rm = TRUE)
  q3 <- stats::quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  lower <- q1 - 1.5 * iqr
  upper <- q3 + 1.5 * iqr
  pmin(pmax(x, lower), upper)
}

remove_outlier_rows <- function(df, cols) {
  keep <- rep(TRUE, nrow(df))
  for (col in cols) {
    x <- df[[col]]
    if (!is.numeric(x)) {
      next
    }
    q1 <- stats::quantile(x, 0.25, na.rm = TRUE)
    q3 <- stats::quantile(x, 0.75, na.rm = TRUE)
    iqr <- q3 - q1
    lower <- q1 - 1.5 * iqr
    upper <- q3 + 1.5 * iqr
    keep <- keep & (is.na(x) | (x >= lower & x <= upper))
  }
  df[keep, , drop = FALSE]
}

coerce_dates <- function(x) {
  if (inherits(x, "Date")) {
    return(list(value = x, converted = TRUE))
  }
  if (inherits(x, "POSIXct") || inherits(x, "POSIXt")) {
    return(list(value = as.Date(x), converted = TRUE))
  }

  if (is.factor(x)) {
    x <- as.character(x)
  }

  if (!is.character(x)) {
    return(list(value = x, converted = FALSE))
  }

  trimmed <- trimws(x)
  if (!length(trimmed)) {
    return(list(value = x, converted = FALSE))
  }

  candidate_formats <- c(
    "%Y-%m-%d",
    "%m/%d/%Y",
    "%d/%m/%Y",
    "%Y/%m/%d",
    "%m-%d-%Y",
    "%d-%b-%Y",
    "%b %d, %Y"
  )

  valid_mask <- is.na(trimmed) | trimmed == ""
  combined_parsed <- rep(as.Date(NA), length(trimmed))

  for (fmt in candidate_formats) {
    unresolved <- !valid_mask & is.na(combined_parsed)
    if (!any(unresolved)) {
      break
    }
    parsed <- suppressWarnings(as.Date(trimmed[unresolved], format = fmt))
    combined_parsed[unresolved] <- parsed
  }

  unresolved <- !valid_mask & is.na(combined_parsed)
  if (any(unresolved)) {
    combined_parsed[unresolved] <- suppressWarnings(as.Date(trimmed[unresolved]))
  }

  parsed_share <- mean(valid_mask | !is.na(combined_parsed))
  if (is.nan(parsed_share) || parsed_share < 0.8) {
    return(list(value = x, converted = FALSE))
  }

  combined_parsed[valid_mask] <- as.Date(NA)
  list(value = combined_parsed, converted = TRUE)
}

read_uploaded_data <- function(path, ext) {
  ext <- tolower(ext)
  if (ext == "csv") {
    return(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (ext %in% c("tsv", "txt")) {
    return(read.delim(path, stringsAsFactors = FALSE, check.names = FALSE))
  }
  if (ext %in% c("xls", "xlsx")) {
    return(readxl::read_excel(path) |> as.data.frame(check.names = FALSE))
  }
  if (ext == "json") {
    read_ndjson <- function(path) {
      lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
      lines <- trimws(lines)
      lines <- lines[nzchar(lines)]
      if (!length(lines)) {
        stop("The uploaded JSON file is empty.")
      }

      records <- lapply(seq_along(lines), function(i) {
        tryCatch(
          jsonlite::fromJSON(lines[[i]], simplifyVector = FALSE),
          error = function(e) {
            stop(sprintf("Invalid JSON on line %d: %s", i, conditionMessage(e)))
          }
        )
      })

      if (!all(vapply(records, is.list, logical(1)))) {
        stop("NDJSON files must contain one JSON object per line.")
      }

      all_names <- unique(unlist(lapply(records, names), use.names = FALSE))
      rows <- lapply(records, function(rec) {
        row <- setNames(vector("list", length(all_names)), all_names)
        for (nm in all_names) {
          value <- rec[[nm]]
          if (is.null(value)) {
            row[[nm]] <- NA
          } else if (length(value) == 1 && (is.atomic(value) || inherits(value, "Date") || inherits(value, "POSIXt"))) {
            row[[nm]] <- value
          } else {
            row[[nm]] <- as.character(jsonlite::toJSON(value, auto_unbox = TRUE, null = "null"))
          }
        }
        as.data.frame(row, check.names = FALSE, stringsAsFactors = FALSE)
      })
      dplyr::bind_rows(rows)
    }

    normalize_json_value <- function(x) {
      if (is.null(x)) {
        return(NA)
      }
      if (length(x) == 1 && (is.atomic(x) || inherits(x, "Date") || inherits(x, "POSIXt"))) {
        return(x)
      }
      as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
    }

    records_to_df <- function(records) {
      if (!length(records)) {
        return(data.frame())
      }
      all_names <- unique(unlist(lapply(records, names), use.names = FALSE))
      if (!length(all_names)) {
        return(data.frame(value = vapply(records, normalize_json_value, character(1)), stringsAsFactors = FALSE))
      }

      rows <- lapply(records, function(rec) {
        row <- setNames(vector("list", length(all_names)), all_names)
        for (nm in all_names) {
          row[[nm]] <- normalize_json_value(rec[[nm]])
        }
        as.data.frame(row, check.names = FALSE, stringsAsFactors = FALSE)
      })
      dplyr::bind_rows(rows)
    }

    normalize_json_payload <- function(payload) {
      if (is.data.frame(payload)) {
        return(as.data.frame(jsonlite::flatten(payload), check.names = FALSE, stringsAsFactors = FALSE))
      }

      if (!is.list(payload)) {
        return(data.frame(value = normalize_json_value(payload), stringsAsFactors = FALSE))
      }

      if (!length(payload)) {
        return(data.frame())
      }

      if (!is.null(names(payload))) {
        record_array_index <- which(vapply(payload, function(x) {
          is.list(x) && length(x) > 0 &&
            all(vapply(x, function(y) is.list(y) || is.data.frame(y), logical(1)))
        }, logical(1)))
        if (length(record_array_index)) {
          return(records_to_df(payload[[record_array_index[1]]]))
        }
      }

      if (!is.null(names(payload)) && length(names(payload)) == length(payload) &&
          all(vapply(payload, function(x) {
            is.atomic(x) || is.factor(x) || inherits(x, "Date") || inherits(x, "POSIXt")
          }, logical(1)))) {
        lengths <- vapply(payload, length, integer(1))
        if (length(unique(lengths)) == 1) {
          return(as.data.frame(payload, check.names = FALSE, stringsAsFactors = FALSE))
        }
        return(as.data.frame(lapply(payload, normalize_json_value), check.names = FALSE, stringsAsFactors = FALSE))
      }

      if (all(vapply(payload, function(x) is.list(x) || is.data.frame(x), logical(1)))) {
        return(records_to_df(payload))
      }

      nested_candidates <- lapply(payload, function(x) {
        tryCatch(normalize_json_payload(x), error = function(e) NULL)
      })
      nested_candidates <- Filter(function(x) !is.null(x) && ncol(x) > 0, nested_candidates)
      if (length(nested_candidates)) {
        candidate_score <- vapply(nested_candidates, function(df) max(1, nrow(df)) * max(1, ncol(df)), numeric(1))
        best_candidate <- nested_candidates[[which.max(candidate_score)]]
        if (nrow(best_candidate) > 1 || length(nested_candidates) == 1) {
          return(best_candidate)
        }
      }

      if (!is.null(names(payload))) {
        return(as.data.frame(lapply(payload, normalize_json_value), check.names = FALSE, stringsAsFactors = FALSE))
      }

      data.frame(value = vapply(payload, normalize_json_value, character(1)), stringsAsFactors = FALSE)
    }

    payload <- tryCatch(
      jsonlite::fromJSON(path, simplifyVector = FALSE),
      error = function(e) {
        msg <- conditionMessage(e)
        if (grepl("extra data|trailing garbage", msg, ignore.case = TRUE)) {
          return(read_ndjson(path))
        }
        stop(e)
      }
    )
    if (is.data.frame(payload)) {
      return(as.data.frame(payload, check.names = FALSE, stringsAsFactors = FALSE))
    }
    return(normalize_json_payload(payload))
  }
  if (ext == "rds") {
    payload <- readRDS(path)
    if (is.data.frame(payload)) {
      return(payload)
    }
    return(as.data.frame(payload, check.names = FALSE))
  }
  stop("Unsupported file type. Please upload CSV, TSV/TXT, Excel, JSON, or RDS.")
}

preview_table <- function(df, n = 10) {
  if (is.null(df) || !nrow(df)) {
    return(data.frame(Message = "No rows available to display."))
  }
  utils::head(df, n)
}

empty_table_message <- function(message) {
  data.frame(Message = message, check.names = FALSE, stringsAsFactors = FALSE)
}

default_plot_x <- function(df, plot_type) {
  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]
  grouping_cols <- categorical_cols[vapply(df[categorical_cols], function(col) {
    distinct_count <- length(unique(stats::na.omit(as.character(col))))
    distinct_count > 1 && distinct_count <= max(20, ceiling(0.1 * nrow(df)))
  }, logical(1))]
  all_cols <- names(df)

  if (plot_type %in% c("Histogram", "Scatter plot", "Correlation heatmap")) {
    return(if (length(numeric_cols)) numeric_cols[1] else if (length(all_cols)) all_cols[1] else character(0))
  }

  if (plot_type == "Box plot") {
    return(if (length(grouping_cols)) grouping_cols[1] else if (length(categorical_cols)) categorical_cols[1] else if (length(all_cols)) all_cols[1] else character(0))
  }

  if (plot_type == "Bar chart") {
    return(if (length(grouping_cols)) grouping_cols[1] else if (length(categorical_cols)) categorical_cols[1] else if (length(all_cols)) all_cols[1] else character(0))
  }

  if (length(all_cols)) all_cols[1] else character(0)
}

default_plot_y <- function(df, plot_type, x_col = NULL) {
  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  if (!length(numeric_cols)) {
    return(character(0))
  }

  if (plot_type == "Scatter plot") {
    candidates <- setdiff(numeric_cols, x_col)
    return(if (length(candidates)) candidates[1] else numeric_cols[1])
  }

  if (plot_type == "Box plot") {
    return(numeric_cols[1])
  }

  numeric_cols[1]
}

clean_dataset <- function(df, options) {
  log_entries <- c()

  if (isTRUE(options$standardize_names)) {
    names(df) <- safe_names(names(df))
    log_entries <- c(log_entries, "Standardized column names.")
  }

  if (isTRUE(options$trim_whitespace)) {
    char_cols <- names(df)[vapply(df, is.character, logical(1))]
    if (length(char_cols)) {
      df[char_cols] <- lapply(df[char_cols], trimws)
      log_entries <- c(log_entries, "Trimmed whitespace in character columns.")
    }
  }

  if (isTRUE(options$coerce_date_columns)) {
    converted_cols <- character(0)
    for (col in names(df)) {
      result <- tryCatch(
        coerce_dates(df[[col]]),
        error = function(e) list(value = df[[col]], converted = FALSE)
      )
      df[[col]] <- result$value
      if (isTRUE(result$converted)) {
        converted_cols <- c(converted_cols, col)
      }
    }
    if (length(converted_cols)) {
      log_entries <- c(log_entries, paste("Converted date-like columns:", paste(converted_cols, collapse = ", ")))
    } else {
      log_entries <- c(log_entries, "No date-like columns were detected.")
    }
  }

  if (isTRUE(options$remove_duplicates)) {
    before <- nrow(df)
    df <- unique(df)
    log_entries <- c(log_entries, paste0("Removed ", before - nrow(df), " duplicate rows."))
  }

  numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
  categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]

  if (identical(options$numeric_missing, "Remove rows") && length(numeric_cols)) {
    before <- nrow(df)
    keep <- stats::complete.cases(df[numeric_cols])
    df <- df[keep, , drop = FALSE]
    log_entries <- c(log_entries, paste0("Removed ", before - nrow(df), " rows with numeric missing values."))
  } else if (options$numeric_missing %in% c("Median imputation", "Mean imputation", "Replace with 0")) {
    for (col in numeric_cols) {
      x <- df[[col]]
      if (!anyNA(x)) {
        next
      }
      fill_value <- switch(
        options$numeric_missing,
        "Median imputation" = stats::median(x, na.rm = TRUE),
        "Mean imputation" = mean(x, na.rm = TRUE),
        "Replace with 0" = 0
      )
      if (is.na(fill_value)) {
        fill_value <- 0
      }
      x[is.na(x)] <- fill_value
      df[[col]] <- x
    }
    log_entries <- c(log_entries, paste("Applied", options$numeric_missing, "to numeric columns."))
  }

  if (identical(options$categorical_missing, "Remove rows") && length(categorical_cols)) {
    before <- nrow(df)
    keep <- stats::complete.cases(df[categorical_cols])
    df <- df[keep, , drop = FALSE]
    log_entries <- c(log_entries, paste0("Removed ", before - nrow(df), " rows with categorical missing values."))
  } else if (options$categorical_missing %in% c("Mode imputation", "Replace with 'Missing'")) {
    for (col in categorical_cols) {
      x <- as.character(df[[col]])
      if (!anyNA(x) && !any(x == "")) {
        next
      }
      fill_value <- if (identical(options$categorical_missing, "Mode imputation")) mode_value(x) else "Missing"
      x[is.na(x) | x == ""] <- fill_value
      df[[col]] <- x
    }
    log_entries <- c(log_entries, paste("Applied", options$categorical_missing, "to categorical columns."))
  }

  if (!is.null(options$scaling_method) && options$scaling_method != "None" && length(options$scaling_columns)) {
    for (col in options$scaling_columns) {
      if (!is.numeric(df[[col]])) {
        next
      }
      df[[col]] <- if (identical(options$scaling_method, "Z-score")) {
        as.numeric(scale(df[[col]]))
      } else {
        min_max_scale(df[[col]])
      }
    }
    log_entries <- c(log_entries, paste("Applied", options$scaling_method, "scaling to:", paste(options$scaling_columns, collapse = ", ")))
  }

  if (identical(options$outlier_method, "Cap with IQR bounds") && length(options$outlier_columns)) {
    for (col in options$outlier_columns) {
      if (is.numeric(df[[col]])) {
        df[[col]] <- cap_outliers(df[[col]])
      }
    }
    log_entries <- c(log_entries, paste("Capped outliers in:", paste(options$outlier_columns, collapse = ", ")))
  } else if (identical(options$outlier_method, "Remove rows with outliers") && length(options$outlier_columns)) {
    before <- nrow(df)
    df <- remove_outlier_rows(df, options$outlier_columns)
    log_entries <- c(log_entries, paste0("Removed ", before - nrow(df), " rows with outliers."))
  }

  if (identical(options$encoding_method, "Label encode") && length(options$encoding_columns)) {
    for (col in options$encoding_columns) {
      df[[paste0(col, "_encoded")]] <- as.integer(factor(df[[col]]))
    }
    log_entries <- c(log_entries, paste("Label encoded:", paste(options$encoding_columns, collapse = ", ")))
  }

  if (!length(log_entries)) {
    log_entries <- "No cleaning transformation selected."
  }

  list(data = df, log = log_entries)
}

apply_feature_engineering <- function(df, action, params) {
  new_cols <- character(0)
  feature_name <- safe_names(params$new_feature_name %||% "")
  if (!nzchar(feature_name)) {
    feature_name <- "new_feature"
  }

  if (identical(action, "None")) {
    return(list(
      data = df,
      new_cols = character(0),
      message = "Choose a feature action before adding a feature."
    ))
  }

  if (identical(action, "Log transform")) {
    selected_col <- params$feature_num_col
    if (is.null(selected_col) || !nzchar(selected_col) || !selected_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select a numeric column before adding the log-transformed feature."))
    }
    df[[feature_name]] <- log1p(pmax(df[[selected_col]], 0))
    new_cols <- feature_name
    message <- paste("Created log-transformed feature from", selected_col)
  } else if (identical(action, "Square root transform")) {
    selected_col <- params$feature_num_col
    if (is.null(selected_col) || !nzchar(selected_col) || !selected_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select a numeric column before adding the square-root feature."))
    }
    df[[feature_name]] <- sqrt(pmax(df[[selected_col]], 0))
    new_cols <- feature_name
    message <- paste("Created square-root feature from", selected_col)
  } else if (identical(action, "Binning")) {
    selected_col <- params$feature_num_col
    if (is.null(selected_col) || !nzchar(selected_col) || !selected_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select a numeric column before creating bins."))
    }
    bins <- max(2, params$bin_count %||% 4)
    df[[feature_name]] <- cut(df[[selected_col]], breaks = bins, include.lowest = TRUE)
    new_cols <- feature_name
    message <- paste("Created binned feature from", selected_col)
  } else if (identical(action, "Interaction term")) {
    first_col <- params$feature_num_col
    second_col <- params$feature_num_col_2
    if (is.null(first_col) || is.null(second_col) ||
        !nzchar(first_col) || !nzchar(second_col) ||
        !first_col %in% names(df) || !second_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select two numeric columns before creating an interaction term."))
    }
    df[[feature_name]] <- df[[first_col]] * df[[second_col]]
    new_cols <- feature_name
    message <- paste("Created interaction term from", first_col, "and", second_col)
  } else if (identical(action, "Ratio feature")) {
    first_col <- params$feature_num_col
    second_col <- params$feature_num_col_2
    if (is.null(first_col) || is.null(second_col) ||
        !nzchar(first_col) || !nzchar(second_col) ||
        !first_col %in% names(df) || !second_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select numerator and denominator columns before creating a ratio feature."))
    }
    denominator <- ifelse(df[[second_col]] == 0, NA, df[[second_col]])
    df[[feature_name]] <- df[[first_col]] / denominator
    new_cols <- feature_name
    message <- paste("Created ratio feature from", first_col, "and", second_col)
  } else if (identical(action, "Date parts")) {
    selected_col <- params$feature_date_col
    if (is.null(selected_col) || !nzchar(selected_col) || !selected_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select a date column before extracting date parts."))
    }
    new_cols <- c(paste0(feature_name, "_year"), paste0(feature_name, "_month"), paste0(feature_name, "_weekday"))
    df[[new_cols[1]]] <- format(df[[selected_col]], "%Y")
    df[[new_cols[2]]] <- format(df[[selected_col]], "%m")
    df[[new_cols[3]]] <- weekdays(df[[selected_col]])
    message <- paste("Extracted date parts from", selected_col)
  } else if (identical(action, "One-hot encode")) {
    selected_col <- params$feature_cat_col
    if (is.null(selected_col) || !nzchar(selected_col) || !selected_col %in% names(df)) {
      return(list(data = df, new_cols = character(0), message = "Select a categorical column before one-hot encoding."))
    }
    dummy <- stats::model.matrix(~ . - 1, data = data.frame(value = factor(df[[selected_col]])))
    dummy <- as.data.frame(dummy)
    names(dummy) <- paste0(feature_name, "_", safe_names(sub("^value", "", names(dummy))))
    new_cols <- names(dummy)
    df <- bind_cols(df, dummy)
    message <- paste("Created one-hot encoded columns from", selected_col)
  } else {
    message <- "Choose a feature action before adding a feature."
  }

  list(data = df, new_cols = new_cols, message = message)
}

filter_dataset <- function(df, filter_column, filter_range = NULL, filter_levels = NULL) {
  if (is.null(filter_column) || identical(filter_column, "None") || !filter_column %in% names(df)) {
    return(df)
  }

  col <- df[[filter_column]]
  if (is.numeric(col) && !is.null(filter_range)) {
    keep <- !is.na(col) & col >= filter_range[1] & col <= filter_range[2]
    return(df[keep, , drop = FALSE])
  }
  if (!is.numeric(col) && !is.null(filter_levels)) {
    return(df[as.character(col) %in% filter_levels, , drop = FALSE])
  }
  df
}

build_eda_plot <- function(df, plot_type, plot_x, plot_y, plot_color) {
  shiny::validate(shiny::need(nrow(df) > 0, "No rows available for plotting after the current filters."))
  use_color <- !is.null(plot_color) && plot_color != "None" && plot_color %in% names(df)

  if (plot_type == "Histogram") {
    shiny::validate(shiny::need(!is.null(plot_x) && plot_x %in% names(df), "Choose an X variable."))
    shiny::validate(shiny::need(is.numeric(df[[plot_x]]), "Histogram requires a numeric X variable."))
    return(
      ggplot(df, aes(x = .data[[plot_x]])) +
        geom_histogram(fill = "#1b4965", color = "white", bins = 20) +
        labs(x = plot_x, y = "Count")
    )
  }

  if (plot_type == "Scatter plot") {
    shiny::validate(shiny::need(!is.null(plot_x) && plot_x %in% names(df), "Choose an X variable."))
    shiny::validate(shiny::need(!is.null(plot_y) && plot_y %in% names(df), "Choose a Y variable."))
    shiny::validate(shiny::need(is.numeric(df[[plot_x]]) && is.numeric(df[[plot_y]]), "Scatter plot requires numeric X and Y variables."))
    if (use_color) {
      return(
        ggplot(df, aes(x = .data[[plot_x]], y = .data[[plot_y]], color = .data[[plot_color]])) +
          geom_point(size = 3, alpha = 0.7) +
          geom_smooth(method = "lm", se = FALSE, color = "#5fa8d3")
      )
    }
    return(
      ggplot(df, aes(x = .data[[plot_x]], y = .data[[plot_y]])) +
        geom_point(size = 3, alpha = 0.7, color = "#1b4965") +
        geom_smooth(method = "lm", se = FALSE, color = "#5fa8d3")
    )
  }

  if (plot_type == "Box plot") {
    shiny::validate(shiny::need(!is.null(plot_x) && plot_x %in% names(df), "Choose an X variable."))
    shiny::validate(shiny::need(!is.null(plot_y) && plot_y %in% names(df), "Choose a Y variable."))
    shiny::validate(shiny::need(is.numeric(df[[plot_y]]), "Box plot requires a numeric Y variable."))
    if (use_color) {
      return(
        ggplot(df, aes(x = .data[[plot_x]], y = .data[[plot_y]], fill = .data[[plot_color]])) +
          geom_boxplot(alpha = 0.7) +
          theme(axis.text.x = element_text(angle = 35, hjust = 1))
      )
    }
    return(
      ggplot(df, aes(x = .data[[plot_x]], y = .data[[plot_y]])) +
        geom_boxplot(alpha = 0.7, fill = "#62b6cb") +
        theme(axis.text.x = element_text(angle = 35, hjust = 1))
    )
  }

  if (plot_type == "Bar chart") {
    shiny::validate(shiny::need(!is.null(plot_x) && plot_x %in% names(df), "Choose an X variable."))
    if (use_color) {
      return(
        ggplot(df, aes(x = .data[[plot_x]], fill = .data[[plot_color]])) +
          geom_bar(position = "dodge") +
          theme(axis.text.x = element_text(angle = 35, hjust = 1))
      )
    }
    return(
      ggplot(df, aes(x = .data[[plot_x]])) +
        geom_bar(fill = "#62b6cb") +
        theme(axis.text.x = element_text(angle = 35, hjust = 1))
    )
  }

  numeric_df <- df[, vapply(df, is.numeric, logical(1)), drop = FALSE]
  shiny::validate(shiny::need(ncol(numeric_df) >= 2, "Correlation heatmap needs at least two numeric columns."))
  corr <- stats::cor(numeric_df, use = "pairwise.complete.obs")
  corr_df <- as.data.frame(as.table(corr))
  ggplot(corr_df, aes(Var1, Var2, fill = Freq)) +
    geom_tile() +
    scale_fill_gradient2(low = "#cae9ff", mid = "white", high = "#1d3557", midpoint = 0) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(x = NULL, y = NULL, fill = "Correlation")
}

shared_server <- function(input, output, session) {
  logging_enabled <- reactive({
    isTRUE(session$userData$logging_enabled %||% FALSE)
  })

  current_tab_name <- reactive({
    if (!is.null(input$main_nav_a) && nzchar(input$main_nav_a %||% "")) {
      return(input$main_nav_a)
    }
    if (!is.null(input$main_nav_b) && nzchar(input$main_nav_b %||% "")) {
      return(input$main_nav_b)
    }
    "Guide"
  })

  mark_meaningful_action <- function(trigger_event, event_value = NULL, tab_name = NULL) {
    if (logging_enabled()) {
      log_first_key_action_once(
        session = session,
        trigger_event = trigger_event,
        event_value = event_value,
        tab_name = tab_name
      )
    }
  }

  raw_data_result <- reactive({
    if (identical(input$source_type, "Built-in dataset")) {
      return(list(
        data = as.data.frame(builtin_datasets[[input$builtin_name]], check.names = FALSE),
        error = NULL
      ))
    }

    req(input$upload_file)
    tryCatch({
      ext <- tools::file_ext(input$upload_file$name)
      df <- read_uploaded_data(input$upload_file$datapath, ext)
      list(
        data = as.data.frame(df, check.names = FALSE),
        error = NULL
      )
    }, error = function(e) {
      list(
        data = NULL,
        error = paste("Could not read uploaded file:", conditionMessage(e))
      )
    })
  })

  raw_data <- reactive({
    result <- raw_data_result()
    shiny::validate(shiny::need(is.null(result$error), result$error))
    result$data
  })

  observe({
    result <- raw_data_result()
    if (is.null(result$error) && !is.null(result$data) && nrow(result$data) >= 0) {
      session$userData$dataset_loaded <- TRUE
      if (logging_enabled() && identical(input$source_type %||% "", "Built-in dataset")) {
        session$userData$last_loaded_source <- paste0("sample:", input$builtin_name %||% "")
      }
    }
  })

  observeEvent(input$upload_file, ignoreInit = TRUE, {
    if (is.null(input$upload_file)) {
      return()
    }
    if (!identical(current_tab_name(), "Data")) {
      return()
    }

    log_session_event(
      session = session,
      event_name = "upload_clicked",
      event_value = input$upload_file$name %||% "",
      tab_name = current_tab_name()
    )
    session$userData$dataset_loaded <- TRUE
    session$userData$last_loaded_source <- paste0("upload:", input$upload_file$name %||% "")
    mark_meaningful_action("upload_clicked", input$upload_file$name %||% "", current_tab_name())
  })

  observeEvent(list(input$source_type, input$builtin_name), ignoreInit = TRUE, {
    if (!identical(input$source_type %||% "", "Built-in dataset")) {
      return()
    }
    if (!identical(current_tab_name(), "Data")) {
      return()
    }

    log_session_event(
      session = session,
      event_name = "sample_data_clicked",
      event_value = input$builtin_name %||% "",
      tab_name = current_tab_name()
    )
    session$userData$dataset_loaded <- TRUE
    session$userData$last_loaded_source <- paste0("sample:", input$builtin_name %||% "")
    mark_meaningful_action("sample_data_clicked", input$builtin_name %||% "", current_tab_name())
  })

  output$raw_rows <- renderText({
    result <- raw_data_result()
    if (!is.null(result$error) || is.null(result$data)) {
      return("0")
    }
    nrow(result$data)
  })

  output$raw_cols <- renderText({
    result <- raw_data_result()
    if (!is.null(result$error) || is.null(result$data)) {
      return("0")
    }
    ncol(result$data)
  })

  output$raw_missing <- renderText({
    result <- raw_data_result()
    if (!is.null(result$error) || is.null(result$data)) {
      return("0")
    }
    sum(is.na(result$data))
  })

  output$raw_types <- renderTable({
    result <- raw_data_result()
    if (!is.null(result$error) || is.null(result$data)) {
      return(empty_table_message(if (is.null(result$error)) "No data loaded." else result$error))
    }
    df <- raw_data()
    data.frame(
      Column = names(df),
      Type = vapply(df, function(col) paste(class(col), collapse = ", "), character(1)),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, bordered = TRUE, width = "100%")

  output$raw_preview <- renderTable({
    result <- raw_data_result()
    if (!is.null(result$error) || is.null(result$data)) {
      return(empty_table_message(if (is.null(result$error)) "No data loaded." else result$error))
    }
    preview_table(raw_data())
  }, striped = TRUE, bordered = TRUE, width = "100%")

  cleaned_result <- reactive({
    clean_dataset(
      df = raw_data(),
      options = list(
        standardize_names = input$standardize_names %||% TRUE,
        trim_whitespace = input$trim_whitespace %||% TRUE,
        coerce_date_columns = input$coerce_date_columns %||% FALSE,
        remove_duplicates = input$remove_duplicates %||% FALSE,
        numeric_missing = input$numeric_missing %||% "None",
        categorical_missing = input$categorical_missing %||% "None",
        scaling_method = input$scaling_method %||% "None",
        scaling_columns = input$scaling_columns %||% character(0),
        outlier_method = input$outlier_method %||% "None",
        outlier_columns = input$outlier_columns %||% character(0),
        encoding_method = input$encoding_method %||% "None",
        encoding_columns = input$encoding_columns %||% character(0)
      )
    )
  })

  observeEvent(
    list(
      input$standardize_names,
      input$trim_whitespace,
      input$coerce_date_columns,
      input$remove_duplicates,
      input$numeric_missing,
      input$categorical_missing,
      input$scaling_method,
      input$scaling_columns,
      input$outlier_method,
      input$outlier_columns,
      input$encoding_method,
      input$encoding_columns
    ),
    ignoreInit = TRUE,
    {
      if (!identical(current_tab_name(), "Cleaning")) {
        return()
      }

      session$userData$cleaning_applied <- TRUE
      log_session_event(
        session = session,
        event_name = "cleaning_applied",
        event_value = paste(cleaned_result()$log, collapse = " | "),
        tab_name = current_tab_name()
      )
      mark_meaningful_action("cleaning_applied", NULL, current_tab_name())
      check_and_log_task_completed(session, current_tab_name())
    }
  )

  cleaned_data <- reactive(cleaned_result()$data)

  observe({
    df <- cleaned_data()
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]

    updateCheckboxGroupInput(session, "scaling_columns", choices = numeric_cols, selected = numeric_cols)
    updateCheckboxGroupInput(session, "outlier_columns", choices = numeric_cols, selected = numeric_cols)
    updateCheckboxGroupInput(session, "encoding_columns", choices = categorical_cols, selected = categorical_cols)
  })

  output$scaling_columns_ui <- renderUI({
    df <- cleaned_data()
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    checkboxGroupInput("scaling_columns", "Numeric columns to scale", choices = numeric_cols, selected = numeric_cols)
  })

  output$outlier_columns_ui <- renderUI({
    df <- cleaned_data()
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    checkboxGroupInput("outlier_columns", "Numeric columns for outlier handling", choices = numeric_cols, selected = numeric_cols)
  })

  output$encoding_columns_ui <- renderUI({
    df <- cleaned_data()
    categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]
    checkboxGroupInput("encoding_columns", "Categorical columns to encode", choices = categorical_cols, selected = categorical_cols)
  })

  output$clean_rows <- renderText({
    nrow(cleaned_data())
  })

  output$clean_cols <- renderText({
    ncol(cleaned_data())
  })

  output$clean_missing <- renderText({
    sum(is.na(cleaned_data()))
  })

  output$clean_log <- renderText({
    paste(cleaned_result()$log, collapse = "\n")
  })

  output$clean_preview <- renderTable({
    preview_table(cleaned_data())
  }, striped = TRUE, bordered = TRUE, width = "100%")

  output$feature_controls <- renderUI({
    df <- cleaned_data()
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    date_cols <- names(df)[vapply(df, inherits, logical(1), what = "Date")]
    categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]

    switch(
      input$feature_action,
      "Log transform" = tagList(
        selectInput("feature_num_col", "Numeric column", choices = numeric_cols),
        helpText("Creates log1p(x), which safely handles zeros.")
      ),
      "Square root transform" = tagList(
        selectInput("feature_num_col", "Numeric column", choices = numeric_cols),
        helpText("Creates sqrt(pmax(x, 0)) to avoid invalid values.")
      ),
      "Binning" = tagList(
        selectInput("feature_num_col", "Numeric column", choices = numeric_cols),
        numericInput("bin_count", "Number of bins", value = 4, min = 2, max = 20)
      ),
      "Interaction term" = tagList(
        selectInput("feature_num_col", "First numeric column", choices = numeric_cols),
        selectInput("feature_num_col_2", "Second numeric column", choices = numeric_cols)
      ),
      "Ratio feature" = tagList(
        selectInput("feature_num_col", "Numerator column", choices = numeric_cols),
        selectInput("feature_num_col_2", "Denominator column", choices = numeric_cols)
      ),
      "Date parts" = tagList(
        selectInput("feature_date_col", "Date column", choices = date_cols)
      ),
      "One-hot encode" = tagList(
        selectInput("feature_cat_col", "Categorical column", choices = categorical_cols)
      ),
      helpText("Select a feature action to generate new columns.")
    )
  })

  engineered_state <- reactiveValues(
    data = NULL,
    engineered_cols = character(0),
    message = "No engineered feature created."
  )

  observeEvent(cleaned_data(), {
    engineered_state$data <- cleaned_data()
    engineered_state$engineered_cols <- character(0)
    engineered_state$message <- "Engineered dataset reset from the latest cleaning step."
  })

  observeEvent(input$add_feature, {
    req(engineered_state$data)
    result <- apply_feature_engineering(
      df = engineered_state$data,
      action = input$feature_action,
      params = list(
        new_feature_name = input$new_feature_name,
        feature_num_col = input$feature_num_col,
        feature_num_col_2 = input$feature_num_col_2,
        feature_date_col = input$feature_date_col,
        feature_cat_col = input$feature_cat_col,
        bin_count = input$bin_count
      )
    )
    engineered_state$data <- result$data
    engineered_state$engineered_cols <- unique(c(engineered_state$engineered_cols, result$new_cols))
    engineered_state$message <- result$message

    if (length(result$new_cols)) {
      session$userData$feature_engineering_applied <- TRUE
      log_session_event(
        session = session,
        event_name = "feature_engineering_applied",
        event_value = paste(result$new_cols, collapse = "|"),
        tab_name = current_tab_name()
      )
      mark_meaningful_action("feature_engineering_applied", paste(result$new_cols, collapse = "|"), current_tab_name())
      check_and_log_task_completed(session, current_tab_name())
    }
  })

  observeEvent(input$delete_feature, {
    req(engineered_state$data)
    cols_to_delete <- intersect(input$delete_features, names(engineered_state$data))
    if (!length(cols_to_delete)) {
      engineered_state$message <- "Select at least one engineered feature to delete."
      return()
    }

    engineered_state$data <- engineered_state$data[, setdiff(names(engineered_state$data), cols_to_delete), drop = FALSE]
    engineered_state$engineered_cols <- setdiff(engineered_state$engineered_cols, cols_to_delete)
    engineered_state$message <- paste("Deleted engineered feature(s):", paste(cols_to_delete, collapse = ", "))
  })

  engineered_data <- reactive({
    req(engineered_state$data)
    engineered_state$data
  })

  output$engineered_rows <- renderText({
    nrow(engineered_data())
  })

  output$engineered_cols <- renderText({
    ncol(engineered_data())
  })

  output$feature_message <- renderText({
    engineered_state$message
  })

  output$engineered_preview <- renderTable({
    preview_table(engineered_data())
  }, striped = TRUE, bordered = TRUE, width = "100%")

  output$delete_feature_ui <- renderUI({
    checkboxGroupInput(
      "delete_features",
      "Engineered features",
      choices = engineered_state$engineered_cols,
      selected = character(0)
    )
  })

  output$download_engineered <- downloadHandler(
    filename = function() {
      paste0("engineered_dataset_", Sys.Date(), ".csv")
    },
    content = function(file) {
      utils::write.csv(engineered_data(), file, row.names = FALSE)
    }
  )

  observe({
    df <- engineered_data()
    cols <- names(df)
    updateSelectInput(session, "filter_column", choices = c("None", cols), selected = "None")

    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]
    all_cols <- names(df)
    plot_type <- if (is.null(input$plot_type)) "Histogram" else input$plot_type
    selected_x <- default_plot_x(df, plot_type)
    selected_y <- default_plot_y(df, plot_type, selected_x)

    updateSelectInput(session, "plot_x", choices = all_cols, selected = selected_x)
    updateSelectInput(session, "plot_y", choices = numeric_cols, selected = selected_y)
    updateSelectInput(session, "plot_color", choices = c("None", categorical_cols), selected = "None")
  })

  output$filter_control <- renderUI({
    df <- engineered_data()
    req(input$filter_column)

    if (input$filter_column == "None" || !input$filter_column %in% names(df)) {
      return(helpText("Choose a column to activate interactive filtering."))
    }

    col <- df[[input$filter_column]]
    if (is.numeric(col)) {
      rng <- range(col, na.rm = TRUE)
      sliderInput("filter_range", "Numeric range", min = floor(rng[1]), max = ceiling(rng[2]), value = rng)
    } else {
      choices <- unique(as.character(col))
      selectInput("filter_levels", "Categories", choices = choices, selected = choices, multiple = TRUE)
    }
  })

  filtered_data <- reactive({
    filter_dataset(
      df = engineered_data(),
      filter_column = input$filter_column,
      filter_range = input$filter_range,
      filter_levels = input$filter_levels
    )
  })

  observeEvent(list(input$main_nav_a, input$main_nav_b), ignoreInit = TRUE, {
    if (!identical(current_tab_name(), "EDA")) {
      return()
    }

    session$userData$eda_generated <- TRUE
    log_session_event(
      session = session,
      event_name = "eda_generated",
      event_value = input$plot_type %||% "Histogram",
      tab_name = current_tab_name()
    )
    mark_meaningful_action("eda_generated", input$plot_type %||% "Histogram", current_tab_name())
    check_and_log_task_completed(session, current_tab_name())
  })

  observeEvent(
    list(
      input$plot_type,
      input$plot_x,
      input$plot_y,
      input$plot_color,
      input$filter_column,
      input$filter_range,
      input$filter_levels
    ),
    ignoreInit = TRUE,
    {
      if (!identical(current_tab_name(), "EDA")) {
        return()
      }

      session$userData$eda_generated <- TRUE
      log_session_event(
        session = session,
        event_name = "eda_generated",
        event_value = paste(
          "plot_type=", input$plot_type %||% "",
          ";plot_x=", input$plot_x %||% "",
          ";plot_y=", input$plot_y %||% "",
          sep = ""
        ),
        tab_name = current_tab_name()
      )
      mark_meaningful_action("eda_generated", input$plot_type %||% "", current_tab_name())
      check_and_log_task_completed(session, current_tab_name())
    }
  )

  output$plot_x_ui <- renderUI({
    df <- filtered_data()
    cols <- names(df)
    selected <- input$plot_x
    if (is.null(selected) || !selected %in% cols) {
      selected <- default_plot_x(df, input$plot_type)
    }
    selectInput("plot_x", "X variable", choices = cols, selected = selected)
  })

  output$plot_y_ui <- renderUI({
    df <- filtered_data()
    numeric_cols <- names(df)[vapply(df, is.numeric, logical(1))]
    if (!length(numeric_cols)) {
      return(NULL)
    }
    selected <- input$plot_y
    if (is.null(selected) || !selected %in% numeric_cols) {
      selected <- default_plot_y(df, input$plot_type, input$plot_x)
    }
    selectInput("plot_y", "Y variable", choices = numeric_cols, selected = selected)
  })

  output$plot_color_ui <- renderUI({
    df <- filtered_data()
    categorical_cols <- names(df)[vapply(df, function(col) is.character(col) || is.factor(col), logical(1))]
    selectInput("plot_color", "Color group", choices = c("None", categorical_cols), selected = "None")
  })

  output$eda_plot <- renderPlot({
    build_eda_plot(
      df = filtered_data(),
      plot_type = input$plot_type,
      plot_x = input$plot_x,
      plot_y = input$plot_y,
      plot_color = input$plot_color
    )
  }, height = function() 600, res = 110)

  output$eda_summary <- renderTable({
    df <- filtered_data()
    numeric_df <- df[, vapply(df, is.numeric, logical(1)), drop = FALSE]
    if (!ncol(numeric_df)) {
      return(data.frame(Message = "No numeric columns available for summary statistics."))
    }

    data.frame(
      Variable = names(numeric_df),
      Mean = vapply(numeric_df, mean, numeric(1), na.rm = TRUE),
      Median = vapply(numeric_df, stats::median, numeric(1), na.rm = TRUE),
      SD = vapply(numeric_df, stats::sd, numeric(1), na.rm = TRUE),
      Missing = vapply(numeric_df, function(col) sum(is.na(col)), numeric(1)),
      check.names = FALSE
    )
  }, striped = TRUE, bordered = TRUE, width = "100%")

  output$eda_preview <- renderTable({
    preview_table(filtered_data())
  }, striped = TRUE, bordered = TRUE, width = "100%")
}
