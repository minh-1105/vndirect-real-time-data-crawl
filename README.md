# VNDIRECT Real-Time Data Crawl

Repo nay gom cac script thu nghiem de lay du lieu gia chung khoan tu he thong VNDIRECT, bao gom:

- `snapshot.py`: goi snapshot API theo danh sach ma.
- `realtime.py`: websocket realtime cu.
- `vndirect_realtime.py`: MQTT realtime.
- `parser_message.py`: parser cho cac ban tin `SP`, `BA`, `MI`, `DE`.
- `generate_bang_gia.py`: chon 5 ma co phieu va ghi ket qua vao `bang_gia_chung_khoan.txt`.

## Luu y hien tai

- Endpoint snapshot public dang tra ve du lieu obfuscate, nen khong phu hop de map truc tiep thanh bang gia.
- `generate_bang_gia.py` hien dung MQTT realtime feed.
- Neu dang ngoai gio giao dich, script co the ket noi thanh cong nhung khong nhan duoc ban tin nao.

## Cau truc message

- `SP` = `StockPartial`: thong tin tong quan cua ma co phieu, gom gia tham chieu, gia tran, gia san, current price...
- `BA` = `BidAsk`: top 3 gia mua, gia ban, khoi luong, gia khop neu co.
- `MI` = `MarketInformation`: thong tin chi so thi truong.
- `DE` = `DerivativeOpt`: thong tin phai sinh.

## Yeu cau

- Python 3.10+
- Khuyen nghi dung virtual environment

Dependency toi thieu de chay cac script hien tai:

```text
websockets
paho-mqtt
```

## Cai dat tren Windows

Mo PowerShell trong thu muc du an:

```powershell
cd path\to\vndirect-real-time-data-crawl
```

Tao virtual environment:

```powershell
py -m venv .venv
```

Kich hoat virtual environment:

```powershell
.\.venv\Scripts\Activate.ps1
```

Cai dependency:

```powershell
python -m pip install websockets paho-mqtt
```

## Cai dat tren Linux

Mo terminal trong thu muc du an:

```bash
cd /path/to/vndirect-real-time-data-crawl
```

Tao virtual environment:

```bash
python3 -m venv .venv
```

Kich hoat virtual environment:

```bash
source .venv/bin/activate
```

Cai dependency:

```bash
python -m pip install websockets paho-mqtt
```

## Cach dung

### 1. Chay script tao bang gia cho 5 ma ngau nhien

Windows:

```powershell
.\.venv\Scripts\python.exe generate_bang_gia.py
```

Linux:

```bash
.venv/bin/python generate_bang_gia.py
```

Ket qua duoc ghi vao file:

```text
bang_gia_chung_khoan.txt
```

### 2. Chay script voi 5 ma do ban chi dinh

Windows:

```powershell
.\.venv\Scripts\python.exe generate_bang_gia.py VND FPT HPG SSI VCB
```

Linux:

```bash
.venv/bin/python generate_bang_gia.py VND FPT HPG SSI VCB
```

Rang buoc:

- Phai truyen dung 5 ma.
- 5 ma phai khac nhau.
- Ma phai ton tai trong `StockIDs/*.txt`.

### 3. Chay MQTT realtime truc tiep

Windows:

```powershell
.\.venv\Scripts\python.exe vndirect_realtime.py
```

Linux:

```bash
.venv/bin/python vndirect_realtime.py
```

### 4. Chay websocket realtime cu

Windows:

```powershell
.\.venv\Scripts\python.exe realtime.py
```

Linux:

```bash
.venv/bin/python realtime.py
```

Luu y: websocket host cu co the khong con hoat dong on dinh.

## Cac file chinh

- `generate_bang_gia.py`: script phuc vu yeu cau xuat bang gia 5 ma co phieu.
- `vndirect_realtime.py`: ket noi MQTT host `price-streaming-free.vndirect.com.vn`.
- `snapshot.py`: goi snapshot API.
- `parser_message.py`: parser cac message type.
- `StockIDs/`: danh sach ma HSX, HNX, UPC.

## Xu ly loi thuong gap

- `ModuleNotFoundError`: chua cai dependency trong `.venv`.
- `Name or service not known`: host cu khong con resolve DNS.
- `Khong nhan duoc ban tin realtime nao`: thuong xay ra khi ngoai gio giao dich, hoac ma vua chon chua co du lieu phat sinh.

## Dau ra mong doi

`generate_bang_gia.py` se co gang ghi cac truong sau vao `bang_gia_chung_khoan.txt`:

- Ma chung khoan
- Gia tham chieu
- Gia tran
- Gia san
- Gia mua 1, 2, 3
- Khoi luong mua 1, 2, 3
- Gia ban 1, 2, 3
- Khoi luong ban 1, 2, 3
- Gia khop lenh neu co
- Khoi luong khop lenh neu co
- Thoi gian lay du lieu
