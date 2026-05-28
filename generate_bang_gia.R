#!/usr/bin/env Rscript

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop(
    paste(
      "Missing dependency: jsonlite.",
      "Install it with: install.packages('jsonlite')"
    ),
    call. = FALSE
  )
}

base_dir <- normalizePath(dirname(commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))]), winslash = "/", mustWork = TRUE)
stock_id_dir <- file.path(base_dir, "StockIDs")
output_file <- file.path(base_dir, "bang_gia_chung_khoan.txt")
random_count <- 5L
snapshot_api_url <- "https://price-streaming-api-free.vndirect.com.vn/v2/stocks/snapshot"

pick_value <- function(..., default = "N/A") {
  values <- list(...)
  for (value in values) {
    if (!is.null(value) && !identical(value, "") && !is.na(value)) {
      return(value)
    }
  }
  default
}

load_stock_codes <- function() {
  files <- sort(list.files(stock_id_dir, pattern = "\\.txt$", full.names = TRUE))
  codes <- character()

  for (path in files) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    cleaned <- toupper(trimws(lines))
    cleaned <- cleaned[nzchar(cleaned)]
    codes <- c(codes, cleaned)
  }

  unique_codes <- sort(unique(codes))
  if (length(unique_codes) < random_count) {
    stop(sprintf("Not enough stock codes to select %d random symbols.", random_count), call. = FALSE)
  }

  unique_codes
}

select_codes <- function(all_codes, args) {
  if (length(args) == 0L) {
    return(sample(all_codes, random_count))
  }

  selected_codes <- toupper(trimws(args))
  selected_codes <- selected_codes[nzchar(selected_codes)]

  if (length(selected_codes) != random_count) {
    stop(sprintf("Please provide exactly %d stock symbols.", random_count), call. = FALSE)
  }

  invalid_codes <- selected_codes[!selected_codes %in% all_codes]
  if (length(invalid_codes) > 0L) {
    stop(sprintf("Invalid symbols: %s", paste(invalid_codes, collapse = ", ")), call. = FALSE)
  }

  if (length(unique(selected_codes)) != random_count) {
    stop("All 5 stock symbols must be different.", call. = FALSE)
  }

  selected_codes
}

decode_message <- function(encoded_message) {
  chars <- strsplit(encoded_message, "", fixed = TRUE)[[1]]
  decoded <- mapply(
    function(char, index) intToUtf8(utf8ToInt(char) + ((index - 1L) %% 5L)),
    chars,
    seq_along(chars),
    USE.NAMES = FALSE
  )
  paste(decoded, collapse = "")
}

decode_fields <- function(encoded_message) {
  strsplit(decode_message(encoded_message), "|", fixed = TRUE)[[1]]
}

map_fields <- function(field_names, values) {
  result <- as.list(rep(NA_character_, length(field_names)))
  names(result) <- field_names
  count <- min(length(field_names), length(values))
  result[seq_len(count)] <- as.list(values[seq_len(count)])
  result
}

parse_sfu <- function(values) {
  stock_type <- values[[2]]

  if (identical(stock_type, "ST")) {
    fields <- c(
      "code", "stockType", "floorCode", "basicPrice", "floorPrice", "ceilingPrice",
      "bidPrice01", "bidPrice02", "bidPrice03", "bidPrice04", "bidPrice05",
      "bidPrice06", "bidPrice07", "bidPrice08", "bidPrice09", "bidPrice10",
      "bidQtty01", "bidQtty02", "bidQtty03", "bidQtty04", "bidQtty05",
      "bidQtty06", "bidQtty07", "bidQtty08", "bidQtty09", "bidQtty10",
      "offerPrice01", "offerPrice02", "offerPrice03", "offerPrice04", "offerPrice05",
      "offerPrice06", "offerPrice07", "offerPrice08", "offerPrice09", "offerPrice10",
      "offerQtty01", "offerQtty02", "offerQtty03", "offerQtty04", "offerQtty05",
      "offerQtty06", "offerQtty07", "offerQtty08", "offerQtty09", "offerQtty10",
      "totalBidQtty", "totalOfferQtty", "highestPrice", "lowestPrice",
      "accumulatedVal", "accumulatedVol", "matchPrice", "matchQtty",
      "currentPrice", "currentQtty", "totalRoom", "currentRoom", "iNav",
      "underlyingAsset", "issuer", "exercisePrice", "exerciseRatio",
      "expiryDate", "time", "bv4", "sv4"
    )
    return(map_fields(fields, values))
  }

  fields <- c(
    "code", "stockType", "floorCode", "basicPrice", "floorPrice", "ceilingPrice",
    "bidPrice01", "bidPrice02", "bidPrice03", "bidQtty01", "bidQtty02", "bidQtty03",
    "offerPrice01", "offerPrice02", "offerPrice03", "offerQtty01", "offerQtty02",
    "offerQtty03", "totalBidQtty", "totalOfferQtty", "tradingSessionId",
    "buyForeignQtty", "sellForeignQtty", "highestPrice", "lowestPrice",
    "accumulatedVal", "accumulatedVol", "matchPrice", "matchQtty", "currentPrice",
    "currentQtty", "projectOpen", "totalRoom", "currentRoom", "iNav"
  )
  map_fields(fields, values)
}

fetch_snapshot_rows <- function(selected_codes) {
  query <- paste(utils::URLencode(selected_codes, reserved = TRUE), collapse = ",")
  url <- sprintf("%s?codes=%s", snapshot_api_url, query)
  raw_rows <- jsonlite::fromJSON(url)

  sp_map <- list()
  for (raw_row in raw_rows) {
    fields <- decode_fields(raw_row)
    if (length(fields) == 0L) {
      next
    }

    message_type <- fields[[1]]
    body <- fields[-1]

    if (identical(message_type, "SFU")) {
      data <- parse_sfu(body)
      code <- data$code
      if (!is.null(code) && code %in% selected_codes) {
        sp_map[[code]] <- data
      }
    }
  }

  sp_map
}

merge_stock_data <- function(code, sp_data, fetched_at) {
  list(
    "Mã chứng khoán" = code,
    "Giá tham chiếu" = pick_value(sp_data$basicPrice),
    "Giá trần" = pick_value(sp_data$ceilingPrice),
    "Giá sàn" = pick_value(sp_data$floorPrice),
    "Giá mua 1" = pick_value(sp_data$bidPrice01),
    "Khối lượng mua 1" = pick_value(sp_data$bidQtty01),
    "Giá mua 2" = pick_value(sp_data$bidPrice02),
    "Khối lượng mua 2" = pick_value(sp_data$bidQtty02),
    "Giá mua 3" = pick_value(sp_data$bidPrice03),
    "Khối lượng mua 3" = pick_value(sp_data$bidQtty03),
    "Giá bán 1" = pick_value(sp_data$offerPrice01),
    "Khối lượng bán 1" = pick_value(sp_data$offerQtty01),
    "Giá bán 2" = pick_value(sp_data$offerPrice02),
    "Khối lượng bán 2" = pick_value(sp_data$offerQtty02),
    "Giá bán 3" = pick_value(sp_data$offerPrice03),
    "Khối lượng bán 3" = pick_value(sp_data$offerQtty03),
    "Giá khớp lệnh" = pick_value(sp_data$matchPrice),
    "Khối lượng khớp lệnh" = pick_value(sp_data$matchQtty),
    "Thời gian lấy dữ liệu" = pick_value(sp_data$time, fetched_at)
  )
}

format_block <- function(index, record) {
  lines <- c(sprintf("Co phieu %d", index))
  for (name in names(record)) {
    lines <- c(lines, sprintf("%s: %s", name, record[[name]]))
  }
  paste(lines, collapse = "\n")
}

main <- function() {
  all_codes <- load_stock_codes()
  selected_codes <- select_codes(all_codes, commandArgs(trailingOnly = TRUE))
  fetched_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  sp_map <- fetch_snapshot_rows(selected_codes)

  rows <- lapply(
    selected_codes,
    function(code) merge_stock_data(code, sp_map[[code]], fetched_at)
  )

  content <- paste(
    vapply(seq_along(rows), function(index) format_block(index, rows[[index]]), character(1)),
    collapse = "\n\n"
  )
  writeLines(c(content, ""), output_file, useBytes = TRUE)

  cat("Da chon 5 ma co phieu:\n")
  for (code in selected_codes) {
    cat(sprintf("- %s\n", code))
  }
  cat(sprintf("\nDa luu ket qua vao: %s\n", output_file))
}

main()
