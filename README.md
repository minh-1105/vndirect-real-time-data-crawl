# VNDIRECT Real-Time Data Crawl

## Introduction

This repository contains experimental tools for collecting, decoding, and normalizing Vietnamese stock market data from VNDIRECT services. It supports both snapshot API requests and realtime MQTT/WebSocket streams, with utilities for validating stock symbols, subscribing to market-data topics, parsing encoded payloads, and generating quote-board outputs.

The project includes Python and R implementations for retrieving realtime stock information, including reference price, ceiling price, floor price, top bid/ask levels, matched price, matched quantity, and data retrieval time. It also includes runtime checks for dependencies, network connectivity, invalid symbols, duplicated symbols, and connection timeouts.

Main capabilities include:

- MQTT realtime data collection from `price-streaming-free.vndirect.com.vn`, including topic helpers for stock, transaction, and market-index subscriptions.
- Realtime payload decoding and normalization through `mqtt_decoder.py`.
- Quote-board generation for exactly 5 selected or random stock symbols through `generate_bang_gia.py`.
- Snapshot API examples for retrieving raw VNDIRECT snapshot rows.
- R implementations through `generate_bang_gia.R` and `generate_bang_gia_realtime.R`, including package checks, symbol validation, realtime websocket/MQTT handling, and CSV output generation.
- Stock-symbol lists for HSX, HNX, and UPC in `StockIDs/`.

This repository contains scripts for retrieving stock price data from VNDIRECT services, including:

- `snapshot.py`: calls the snapshot API for a list of stock symbols.
- `realtime.py`: uses the legacy realtime websocket feed.
- `vndirect_realtime.py`: connects to the MQTT realtime feed.
- `parser_message.py`: parses `SP`, `BA`, `MI`, and `DE` messages.
- `generate_bang_gia.py`: selects 5 stock symbols and writes the result to `bang_gia_chung_khoan.txt`.
- `generate_bang_gia_R.txt`: R script that retrieves realtime data and writes the result to `bang_gia_chung_khoan_R_realtime.csv`.


## Current Notes

- The public snapshot endpoint currently returns obfuscated data, so it is not suitable for directly building a quote board.
- `generate_bang_gia.py` currently uses the MQTT realtime feed.
- Outside trading hours, the script may connect successfully but still receive no messages.

## Message Types

- `SP` = `StockPartial`: general stock information such as reference price, ceiling price, floor price, current price, and related fields.
- `BA` = `BidAsk`: top 3 bid prices, ask prices, quantities, and matched price information when available.
- `MI` = `MarketInformation`: market index data.
- `DE` = `DerivativeOpt`: derivatives data.

## Requirements

- Python 3.10+
- A virtual environment is recommended
- R 4.3+ if you want to run the R script

Minimum dependencies required for the current scripts:

```text
websockets
paho-mqtt
```

R packages required for the current realtime R script:

```text
jsonlite
websocket
later
```

## Installation on Windows

Open PowerShell in the project directory:

```powershell
cd path\to\vndirect-real-time-data-crawl
```

Create a virtual environment:

```powershell
py -m venv .venv
```

Activate the virtual environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

Install dependencies:

```powershell
python -m pip install websockets paho-mqtt
```

## Installation on Linux

Open a terminal in the project directory:

```bash
cd /path/to/vndirect-real-time-data-crawl
```

Create a virtual environment:

```bash
python3 -m venv .venv
```

Activate the virtual environment:

```bash
source .venv/bin/activate
```

Install dependencies:

```bash
python -m pip install websockets paho-mqtt
```

Install R packages:

```bash
Rscript -e "install.packages(c('jsonlite','websocket','later'), repos='https://cloud.r-project.org')"
```

## Usage

### 1. Generate a quote board for 5 random stock symbols

Windows:

```powershell
.\.venv\Scripts\python.exe generate_bang_gia.py
```

Linux:

```bash
.venv/bin/python generate_bang_gia.py
```

The result is written to:

```text
bang_gia_chung_khoan.txt
```

### 2. Run the script with 5 specific stock symbols

Windows:

```powershell
.\.venv\Scripts\python.exe generate_bang_gia.py VND FPT HPG SSI VCB
```

Linux:

```bash
.venv/bin/python generate_bang_gia.py VND FPT HPG SSI VCB
```

Constraints:

- You must pass exactly 5 symbols.
- All 5 symbols must be different.
- Each symbol must exist in `StockIDs/*.txt`.

### 3. Run the MQTT realtime feed directly

Windows:

```powershell
.\.venv\Scripts\python.exe vndirect_realtime.py
```

Linux:

```bash
.venv/bin/python vndirect_realtime.py
```

### 4. Run the realtime R script from the command line

The R script supports exactly 5 symbols and writes the result to:

```text
bang_gia_chung_khoan_R_realtime.csv
```

Example:

```bash
Rscript generate_bang_gia_R.txt VND FPT HPG SSI VCB
```

Constraints:

- You must pass exactly 5 symbols.
- All 5 symbols must be different.
- Each symbol must exist in `StockIDs/*.txt`.

### 5. Run the realtime R script in RStudio

Open `generate_bang_gia_R.txt` in RStudio.

Option 1: predefine the symbols, then source the file:

```r
selected_codes_input <- c("VND", "FPT", "HPG", "SSI", "VCB")
source("generate_bang_gia_R.txt")
```

Option 2: just source the file and enter 5 symbols when prompted.

The script will create:

```text
bang_gia_chung_khoan_R_realtime.csv
```

### 6. Run the legacy realtime websocket script

Windows:

```powershell
.\.venv\Scripts\python.exe realtime.py
```

Linux:

```bash
.venv/bin/python realtime.py
```

Note: the legacy websocket host may no longer be stable.

## Main Files

- `generate_bang_gia.py`: generates a quote board for 5 stock symbols.
- `generate_bang_gia_R.txt`: generates a realtime quote board in CSV format for 5 stock symbols and can run in RStudio.
- `vndirect_realtime.py`: connects to the MQTT host `price-streaming-free.vndirect.com.vn`.
- `snapshot.py`: calls the snapshot API.
- `parser_message.py`: parses supported message types.
- `StockIDs/`: contains symbol lists for HSX, HNX, and UPC.

## Common Errors

- `ModuleNotFoundError`: required dependencies are not installed in the active environment.
- `Thieu package R`: required R packages are not installed for `generate_bang_gia_R.txt`.
- `Name or service not known`: the old host can no longer be resolved by DNS.
- `Khong nhan duoc ban tin realtime nao`: this usually happens outside trading hours, or when no realtime updates are available for the selected symbols.

## Expected Output

`generate_bang_gia.py` attempts to write the following fields to `bang_gia_chung_khoan.txt`:

- Stock symbol
- Reference price
- Ceiling price
- Floor price
- Bid prices 1, 2, 3
- Bid quantities 1, 2, 3
- Ask prices 1, 2, 3
- Ask quantities 1, 2, 3
- Matched price, if available
- Matched quantity, if available
- Data retrieval time
