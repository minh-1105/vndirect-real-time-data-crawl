#!/usr/bin/env Rscript


required_packages <- c("jsonlite", "websocket", "later")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0L) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
  stop(
    sprintf("Khong the cai package R: %s", paste(missing_packages, collapse = ", ")),
    call. = FALSE
  )
}

get_script_path <- function() {
  args_all <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args_all, value = TRUE)
  if (length(file_arg) > 0L) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]]), winslash = "/", mustWork = TRUE))
  }

  for (index in rev(seq_len(sys.nframe()))) {
    frame <- sys.frame(index)
    if (exists("ofile", envir = frame, inherits = FALSE)) {
      return(normalizePath(get("ofile", envir = frame, inherits = FALSE), winslash = "/", mustWork = TRUE))
    }
  }

  if (file.exists("generate_bang_gia_R.R")) {
    return(normalizePath("generate_bang_gia_R.R", winslash = "/", mustWork = TRUE))
  }

  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

script_path <- get_script_path()
base_dir <- if (dir.exists(script_path)) script_path else dirname(script_path)
stock_id_dir <- file.path(base_dir, "StockIDs")
output_file <- "/home/minhtb/Documents/R_/bang_gia_chung_khoan_R_realtime.csv"

random_count <- 5L
default_codes <- c("VND", "FPT", "HPG", "SSI", "VCB")
wait_timeout_seconds <- 20
snapshot_api_url <- "https://price-streaming-api-free.vndirect.com.vn/v2/stocks/snapshot"
mqtt_url <- "wss://price-streaming-free.vndirect.com.vn/mqtt"
mqtt_username <- "1d84f25b561f2575"
keepalive_seconds <- 30L

pick_value <- function(..., default = NA_character_) {
  values <- list(...)
  for (value in values) {
    if (!is.null(value) && !identical(value, "") && !is.na(value)) {
      return(as.character(value))
    }
  }
  default
}

build_empty_quote_board <- function() {
  data.frame(
    Ma_CK = character(),
    TC = character(),
    Tran = character(),
    San = character(),
    Gia_Mua_1 = character(),
    KL_Mua_1 = character(),
    Gia_Mua_2 = character(),
    KL_Mua_2 = character(),
    Gia_Mua_3 = character(),
    KL_Mua_3 = character(),
    Gia_Ban_1 = character(),
    KL_Ban_1 = character(),
    Gia_Ban_2 = character(),
    KL_Ban_2 = character(),
    Gia_Ban_3 = character(),
    KL_Ban_3 = character(),
    Gia_Khop_Lenh = character(),
    KL_Khop_Lenh = character(),
    Thoi_Gian = character(),
    stringsAsFactors = FALSE
  )
}

initialize_output_csv <- function() {
  if (!file.exists(output_file)) {
    utils::write.csv(
      build_empty_quote_board(),
      output_file,
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }

  invisible(output_file)
}

load_stock_codes <- function() {
  if (!dir.exists(stock_id_dir)) {
    return(character())
  }

  files <- sort(list.files(stock_id_dir, pattern = "\\.txt$", full.names = TRUE))
  if (length(files) == 0L) {
    return(character())
  }

  codes <- character()

  for (path in files) {
    lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
    cleaned <- toupper(trimws(lines))
    cleaned <- cleaned[nzchar(cleaned)]
    codes <- c(codes, cleaned)
  }

  unique(sort(unique(codes)))
}

parse_codes_text <- function(text) {
  codes <- unlist(strsplit(toupper(trimws(text)), "[,[:space:]]+", perl = TRUE))
  codes[nzchar(codes)]
}

validate_code_format <- function(codes) {
  invalid_codes <- codes[!grepl("^[A-Z0-9]+$", codes)]
  if (length(invalid_codes) > 0L) {
    stop(sprintf("Ma khong dung dinh dang: %s", paste(invalid_codes, collapse = ", ")), call. = FALSE)
  }
}

select_codes <- function(all_codes, args) {
  cli_codes <- toupper(trimws(args))
  cli_codes <- cli_codes[nzchar(cli_codes)]
  if (length(cli_codes) > 0L) {
    selected_codes <- cli_codes
  } else if (exists("selected_codes_input", envir = .GlobalEnv, inherits = FALSE)) {
    selected_codes <- toupper(trimws(get("selected_codes_input", envir = .GlobalEnv, inherits = FALSE)))
    selected_codes <- selected_codes[nzchar(selected_codes)]
  } else if (interactive()) {
    selected_codes <- default_codes
  } else {
    selected_codes <- default_codes
  }

  if (length(selected_codes) == 0L) {
    stop("Chua nhap ma co phieu.", call. = FALSE)
  }

  if (length(selected_codes) != random_count) {
    stop(sprintf("Hay nhap dung %d ma co phieu.", random_count), call. = FALSE)
  }

  if (length(unique(selected_codes)) != random_count) {
    stop("5 ma co phieu phai khac nhau.", call. = FALSE)
  }

  validate_code_format(selected_codes)

  if (length(all_codes) > 0L) {
    invalid_codes <- selected_codes[!selected_codes %in% all_codes]
    if (length(invalid_codes) > 0L) {
      stop(sprintf("Ma khong hop le: %s", paste(invalid_codes, collapse = ", ")), call. = FALSE)
    }
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

parse_stock_message <- function(message_type, values) {
  stock_type <- if (length(values) >= 2L) values[[2]] else NA_character_

  if (identical(message_type, "SFU")) {
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
    return(map_fields(fields, values))
  }

  if (identical(message_type, "SBA")) {
    if (identical(stock_type, "ST")) {
      fields <- c(
        "code", "stockType", "floorCode", "bidPrice01", "bidPrice02", "bidPrice03",
        "bidPrice04", "bidPrice05", "bidPrice06", "bidPrice07", "bidPrice08",
        "bidPrice09", "bidPrice10", "bidQtty01", "bidQtty02", "bidQtty03",
        "bidQtty04", "bidQtty05", "bidQtty06", "bidQtty07", "bidQtty08",
        "bidQtty09", "bidQtty10", "offerPrice01", "offerPrice02", "offerPrice03",
        "offerPrice04", "offerPrice05", "offerPrice06", "offerPrice07", "offerPrice08",
        "offerPrice09", "offerPrice10", "offerQtty01", "offerQtty02", "offerQtty03",
        "offerQtty04", "offerQtty05", "offerQtty06", "offerQtty07", "offerQtty08",
        "offerQtty09", "offerQtty10", "totalBidQtty", "totalOfferQtty"
      )
      return(map_fields(fields, values))
    }

    fields <- c(
      "code", "stockType", "floorCode", "bidPrice01", "bidPrice02", "bidPrice03",
      "bidQtty01", "bidQtty02", "bidQtty03", "offerPrice01", "offerPrice02",
      "offerPrice03", "offerQtty01", "offerQtty02", "offerQtty03",
      "totalBidQtty", "totalOfferQtty", "bv4", "sv4"
    )
    return(map_fields(fields, values))
  }

  if (identical(message_type, "SMA")) {
    fields <- c(
      "code", "stockType", "floorCode", "buyForeignQtty", "sellForeignQtty",
      "highestPrice", "lowestPrice", "accumulatedVal", "accumulatedVol",
      "matchPrice", "matchQtty", "currentPrice", "currentQtty", "totalRoom",
      "currentRoom"
    )
    return(map_fields(fields, values))
  }

  if (identical(message_type, "SBS")) {
    fields <- c("code", "stockType", "floorCode", "basicPrice", "floorPrice", "ceilingPrice")
    return(map_fields(fields, values))
  }

  list(rawFields = values)
}

parse_transaction_message <- function(message_type, values) {
  if (!identical(message_type, "ST")) {
    return(list(rawFields = values))
  }

  fields <- c("symbol", "time", "floorCode", "last", "lastVol", "accumulatedVol", "accumulatedVal")
  map_fields(fields, values)
}

parse_payload <- function(payload) {
  if (!is.character(payload) || length(payload) != 1L || !grepl("|", payload, fixed = TRUE) || !grepl(":", payload, fixed = TRUE)) {
    return(NULL)
  }

  pipe_index <- regexpr("|", payload, fixed = TRUE)[[1]]
  colon_index <- regexpr(":", payload, fixed = TRUE)[[1]]
  room_name <- substring(payload, pipe_index + 1L, colon_index - 1L)

  matches <- gregexpr('"([^"]*)"', payload, perl = TRUE)[[1]]
  if (matches[[1]] == -1L) {
    return(list(roomName = room_name, messages = list()))
  }

  encoded_messages <- regmatches(payload, gregexpr('"([^"]*)"', payload, perl = TRUE))[[1]]
  encoded_messages <- substring(encoded_messages, 2L, nchar(encoded_messages) - 1L)

  messages <- list()
  for (encoded_message in encoded_messages) {
    fields <- decode_fields(encoded_message)
    if (length(fields) == 0L) {
      next
    }

    message_type <- fields[[1]]
    body <- fields[-1]

    data <- switch(
      room_name,
      "S" = parse_stock_message(message_type, body),
      "ST" = parse_transaction_message(message_type, body),
      list(rawFields = body)
    )

    messages[[length(messages) + 1L]] <- list(
      roomName = room_name,
      messageType = message_type,
      data = data
    )
  }

  list(roomName = room_name, messages = messages)
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
      data <- parse_stock_message(message_type, body)
      code <- data$code
      if (!is.null(code) && code %in% selected_codes) {
        sp_map[[code]] <- data
      }
    }
  }

  sp_map
}

stock_topic <- function(symbol, floor_code = "+") {
  sprintf("%s/%s", floor_code, toupper(symbol))
}

transaction_topic <- function(symbol, floor_code = "+") {
  sprintf("T/%s/%s", floor_code, toupper(symbol))
}

int_to_raw2 <- function(value) {
  as.raw(c(bitwShiftR(value, 8L) %% 256L, value %% 256L))
}

encode_utf8_field <- function(text) {
  bytes <- charToRaw(enc2utf8(text))
  c(int_to_raw2(length(bytes)), bytes)
}

encode_remaining_length <- function(value) {
  out <- raw()
  repeat {
    encoded_byte <- value %% 128L
    value <- value %/% 128L
    if (value > 0L) {
      encoded_byte <- bitwOr(encoded_byte, 128L)
    }
    out <- c(out, as.raw(encoded_byte))
    if (value == 0L) {
      break
    }
  }
  out
}

build_packet <- function(packet_type, body, flags = 0L) {
  first_byte <- as.raw(bitwOr(bitwShiftL(packet_type, 4L), flags))
  c(first_byte, encode_remaining_length(length(body)), body)
}

build_connect_packet <- function(client_id, username, keepalive = 30L) {
  variable_header <- c(
    encode_utf8_field("MQTT"),
    as.raw(0x04),
    as.raw(0x82),
    int_to_raw2(keepalive)
  )
  payload <- c(
    encode_utf8_field(client_id),
    encode_utf8_field(username)
  )
  build_packet(1L, c(variable_header, payload))
}

build_subscribe_packet <- function(packet_id, topics) {
  topic_body <- raw()
  for (topic in topics) {
    topic_body <- c(topic_body, encode_utf8_field(topic), as.raw(0x00))
  }
  body <- c(int_to_raw2(packet_id), topic_body)
  build_packet(8L, body, flags = 0x02)
}

build_pingreq_packet <- function() {
  as.raw(c(0xC0, 0x00))
}

build_disconnect_packet <- function() {
  as.raw(c(0xE0, 0x00))
}

decode_remaining_length <- function(buffer, start_index) {
  multiplier <- 1L
  value <- 0L
  consumed <- 0L

  repeat {
    if ((start_index + consumed) > length(buffer)) {
      return(NULL)
    }

    encoded_byte <- as.integer(buffer[[start_index + consumed]])
    value <- value + (bitwAnd(encoded_byte, 127L) * multiplier)
    consumed <- consumed + 1L

    if (bitwAnd(encoded_byte, 128L) == 0L) {
      break
    }

    multiplier <- multiplier * 128L
  }

  list(value = value, consumed = consumed)
}

read_utf8_field <- function(packet, offset) {
  length_value <- bitwShiftL(as.integer(packet[[offset]]), 8L) + as.integer(packet[[offset + 1L]])
  start <- offset + 2L
  end <- start + length_value - 1L
  value <- rawToChar(packet[start:end], multiple = FALSE)
  list(value = value, next_offset = end + 1L)
}

parse_mqtt_packets <- function(buffer) {
  packets <- list()
  offset <- 1L

  while (offset <= length(buffer)) {
    remaining <- decode_remaining_length(buffer, offset + 1L)
    if (is.null(remaining)) {
      break
    }

    header_size <- 1L + remaining$consumed
    packet_end <- offset + header_size + remaining$value - 1L
    if (packet_end > length(buffer)) {
      break
    }

    packets[[length(packets) + 1L]] <- buffer[offset:packet_end]
    offset <- packet_end + 1L
  }

  remaining_buffer <- if (offset <= length(buffer)) buffer[offset:length(buffer)] else raw()
  list(packets = packets, remaining = remaining_buffer)
}

parse_publish_packet <- function(packet_bytes) {
  first_byte <- as.integer(packet_bytes[[1]])
  qos <- bitwAnd(bitwShiftR(first_byte, 1L), 0x03)
  remaining <- decode_remaining_length(packet_bytes, 2L)
  body_offset <- 2L + remaining$consumed
  topic_field <- read_utf8_field(packet_bytes, body_offset)
  next_offset <- topic_field$next_offset

  if (qos > 0L) {
    next_offset <- next_offset + 2L
  }

  payload <- if (next_offset <= length(packet_bytes)) packet_bytes[next_offset:length(packet_bytes)] else raw()
  list(topic = topic_field$value, payload = rawToChar(payload, multiple = FALSE))
}
#Q1
merge_stock_data <- function(code, sp_data, ba_data, fetched_at) {
  sp_data <- if (is.null(sp_data)) list() else sp_data
  ba_data <- if (is.null(ba_data)) list() else ba_data

  data.frame(
    Ma_CK = code,
    TC = pick_value(sp_data$basicPrice),
    Tran = pick_value(sp_data$ceilingPrice),
    San = pick_value(sp_data$floorPrice),
    Gia_Mua_1 = pick_value(ba_data$bidPrice01, sp_data$bidPrice01),
    KL_Mua_1 = pick_value(ba_data$bidQtty01, sp_data$bidQtty01),
    Gia_Mua_2 = pick_value(ba_data$bidPrice02, sp_data$bidPrice02),
    KL_Mua_2 = pick_value(ba_data$bidQtty02, sp_data$bidQtty02),
    Gia_Mua_3 = pick_value(ba_data$bidPrice03, sp_data$bidPrice03),
    KL_Mua_3 = pick_value(ba_data$bidQtty03, sp_data$bidQtty03),
    Gia_Ban_1 = pick_value(ba_data$offerPrice01, sp_data$offerPrice01),
    KL_Ban_1 = pick_value(ba_data$offerQtty01, sp_data$offerQtty01),
    Gia_Ban_2 = pick_value(ba_data$offerPrice02, sp_data$offerPrice02),
    KL_Ban_2 = pick_value(ba_data$offerQtty02, sp_data$offerQtty02),
    Gia_Ban_3 = pick_value(ba_data$offerPrice03, sp_data$offerPrice03),
    KL_Ban_3 = pick_value(ba_data$offerQtty03, sp_data$offerQtty03),
    Gia_Khop_Lenh = pick_value(ba_data$matchPrice, sp_data$matchPrice),
    KL_Khop_Lenh = pick_value(ba_data$matchQtty, sp_data$matchQtty),
    Thoi_Gian = pick_value(ba_data$time, sp_data$time, fetched_at),
    stringsAsFactors = FALSE
  )
}

get_text_by_id <- function(page, id) {
  NA_character_
}

get_stock_data <- function(page, ma_ck, sp_map, ba_map, fetched_at) {
  merge_stock_data(ma_ck, sp_map[[ma_ck]], ba_map[[ma_ck]], fetched_at)
}

collect_realtime_rows <- function(selected_codes) {
  sp_map <- fetch_snapshot_rows(selected_codes)
  ba_map <- list()
  topics <- c(
    vapply(selected_codes, stock_topic, character(1)),
    vapply(selected_codes, transaction_topic, character(1))
  )

  state <- new.env(parent = emptyenv())
  state$connected <- FALSE
  state$subscribed <- FALSE
  state$buffer <- raw()
  state$error <- NULL
  state$publish_count <- 0L
  state$decoded_count <- 0L
  state$transaction_count <- 0L

  client_id <- sprintf("free-user-r-%d", as.integer(Sys.time()))
  connect_packet <- build_connect_packet(client_id, mqtt_username, keepalive_seconds)
  subscribe_packet <- build_subscribe_packet(1L, topics)
  ping_packet <- build_pingreq_packet()
  disconnect_packet <- build_disconnect_packet()

  ws <- websocket::WebSocket$new(
    mqtt_url,
    protocols = "mqtt",
    autoConnect = FALSE
  )

  ws$onOpen(function(event) {
    event$target$send(connect_packet)
  })

  ws$onMessage(function(event) {
    if (!is.raw(event$data)) {
      return()
    }

    state$buffer <- c(state$buffer, event$data)
    parsed <- parse_mqtt_packets(state$buffer)
    state$buffer <- parsed$remaining

    for (packet in parsed$packets) {
      packet_type <- bitwShiftR(as.integer(packet[[1]]), 4L)

      if (packet_type == 2L) {
        state$connected <- TRUE
        event$target$send(subscribe_packet)
        next
      }

      if (packet_type == 9L) {
        state$subscribed <- TRUE
        next
      }

      if (packet_type != 3L) {
        next
      }

      state$publish_count <- state$publish_count + 1L
      publish <- parse_publish_packet(packet)
      parsed_payload <- parse_payload(publish$payload)
      if (is.null(parsed_payload)) {
        next
      }

      for (decoded_message in parsed_payload$messages) {
        state$decoded_count <- state$decoded_count + 1L
        message_type <- decoded_message$messageType
        data <- decoded_message$data

        if (message_type %in% c("SBS", "SMA", "SFU")) {
          code <- data$code
          if (!is.null(code) && code %in% selected_codes) {
            existing <- sp_map[[code]]
            if (is.null(existing)) {
              sp_map[[code]] <- data
            } else {
              existing[names(data)] <- data
              sp_map[[code]] <- existing
            }
          }
        } else if (identical(message_type, "SBA")) {
          code <- data$code
          if (!is.null(code) && code %in% selected_codes) {
            existing <- ba_map[[code]]
            if (is.null(existing)) {
              ba_map[[code]] <- data
            } else {
              existing[names(data)] <- data
              ba_map[[code]] <- existing
            }
          }
        } else if (identical(message_type, "ST")) {
          code <- data$symbol
          if (!is.null(code) && code %in% selected_codes) {
            state$transaction_count <- state$transaction_count + 1L
            existing <- ba_map[[code]]
            update <- list(
              matchPrice = data$last,
              matchQtty = data$lastVol,
              time = data$time
            )
            if (is.null(existing)) {
              ba_map[[code]] <- update
            } else {
              existing[names(update)] <- update
              ba_map[[code]] <- existing
            }
          }
        }
      }
    }
  })

  ws$onError(function(event) {
    state$error <- event$message
  })

  ws$connect()
  start_time <- Sys.time()
  last_ping_at <- Sys.time()

  repeat {
    later::run_now(timeout = 0.1)

    if (!is.null(state$error)) {
      stop(sprintf("Loi ket noi realtime: %s", state$error), call. = FALSE)
    }

    if (difftime(Sys.time(), last_ping_at, units = "secs") >= keepalive_seconds / 2) {
      if (ws$readyState() == 1L) {
        ws$send(ping_packet)
      }
      last_ping_at <- Sys.time()
    }

    if (difftime(Sys.time(), start_time, units = "secs") >= wait_timeout_seconds) {
      break
    }
  }

  if (ws$readyState() == 1L) {
    ws$send(disconnect_packet)
    ws$close()
  }

  list(
    sp_map = sp_map,
    ba_map = ba_map,
    connected = state$connected,
    subscribed = state$subscribed,
    publish_count = state$publish_count,
    decoded_count = state$decoded_count,
    transaction_count = state$transaction_count
  )
}

run_quote_board <- function(selected_codes = NULL) {
  all_codes <- load_stock_codes()
  if (length(all_codes) == 0L) {
    message("Khong tim thay StockIDs. Script se chay voi 5 ma mac dinh hoac ma ban truyen vao.")
  }
  selected_codes <- select_codes(all_codes, if (is.null(selected_codes)) commandArgs(trailingOnly = TRUE) else selected_codes)
  fetched_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  initialize_output_csv()

  rows_data <- tryCatch(
    collect_realtime_rows(selected_codes),
    error = function(err) {
      stop(
        sprintf("Khong lay duoc du lieu realtime: %s", conditionMessage(err)),
        call. = FALSE
      )
    }
  )
  df_ck <- do.call(
    rbind,
    lapply(
      selected_codes,
      function(ma) get_stock_data(NULL, ma, rows_data$sp_map, rows_data$ba_map, fetched_at)
    )
  )

  tryCatch(
    {
      utils::write.csv(
        df_ck,
        output_file,
        row.names = FALSE,
        fileEncoding = "UTF-8"
      )
    },
    error = function(err) {
      stop(sprintf("Khong ghi duoc file CSV: %s", conditionMessage(err)), call. = FALSE)
    }
  )

  cat("Da chon 5 ma co phieu:\n")
  for (code in selected_codes) {
    cat(sprintf("- %s\n", code))
  }
  cat(sprintf("\nTrang thai MQTT: connected=%s, subscribed=%s\n", rows_data$connected, rows_data$subscribed))
  cat(sprintf("So goi PUBLISH nhan duoc: %d\n", rows_data$publish_count))
  cat(sprintf("So message decode duoc: %d\n", rows_data$decoded_count))
  cat(sprintf("So giao dich realtime ST nhan duoc: %d\n", rows_data$transaction_count))
  cat(sprintf("\nDa luu file CSV vao: %s\n", output_file))

  invisible(df_ck)
}

main <- function() {
  run_quote_board()
}

# Cach chay trong RStudio:
# 1. Mo file nay.
# 2. Co the dat truoc: selected_codes_input <- c("VND", "FPT", "HPG", "SSI", "VCB")
# 3. Bam Source. Neu chua dat selected_codes_input, script se hoi nhap 5 ma.

if (sys.nframe() == 0L || interactive()) {
  main()
}
