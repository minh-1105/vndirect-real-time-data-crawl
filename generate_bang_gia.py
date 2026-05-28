import random
import threading
import time
import json
import sys
from datetime import datetime
from pathlib import Path

try:
    from vndirect_realtime import create_client, stock_topic, transaction_topic
except ModuleNotFoundError as exc:
    missing_module = exc.name or "dependency"
    raise SystemExit(
        "Thieu thu vien de chay realtime feed. "
        f"Module bi thieu: {missing_module}. "
        "Hay cai dependency bang lenh: python -m pip install -r requirements.txt"
    ) from exc


BASE_DIR = Path(__file__).resolve().parent
STOCK_ID_DIR = BASE_DIR / "StockIDs"
OUTPUT_FILE = BASE_DIR / "bang_gia_chung_khoan.txt"
RANDOM_COUNT = 5
WAIT_TIMEOUT_SECONDS = 20


def load_stock_codes():
    codes = []
    for path in sorted(STOCK_ID_DIR.glob("*.txt")):
        for line in path.read_text(encoding="utf-8").splitlines():
            code = line.strip().upper()
            if code:
                codes.append(code)
    unique_codes = sorted(set(codes))
    if len(unique_codes) < RANDOM_COUNT:
        raise ValueError(f"Khong du ma co phieu de chon {RANDOM_COUNT} ma ngau nhien.")
    return unique_codes


def select_codes(all_codes, args):
    if not args:
        return random.sample(all_codes, RANDOM_COUNT)

    selected_codes = [code.strip().upper() for code in args if code.strip()]
    if len(selected_codes) != RANDOM_COUNT:
        raise SystemExit(f"Hay truyen dung {RANDOM_COUNT} ma co phieu.")

    valid_codes = set(all_codes)
    invalid_codes = [code for code in selected_codes if code not in valid_codes]
    if invalid_codes:
        raise SystemExit(f"Ma khong hop le: {', '.join(invalid_codes)}")

    if len(set(selected_codes)) != RANDOM_COUNT:
        raise SystemExit("5 ma co phieu phai khac nhau.")

    return selected_codes


def pick_value(*values, default="N/A"):
    for value in values:
        if value not in (None, ""):
            return value
    return default


def format_block(index, record):
    lines = [f"Co phieu {index}"]
    for key, value in record.items():
        lines.append(f"{key}: {value}")
    return "\n".join(lines)


def merge_stock_data(code, sp_data, ba_data, fetched_at):
    sp_data = sp_data or {}
    ba_data = ba_data or {}
    return {
        "Mã chứng khoán": code,
        "Giá tham chiếu": pick_value(sp_data.get("basicPrice")),
        "Giá trần": pick_value(sp_data.get("ceilingPrice")),
        "Giá sàn": pick_value(sp_data.get("floorPrice")),
        "Giá mua 1": pick_value(ba_data.get("bidPrice01")),
        "Khối lượng mua 1": pick_value(ba_data.get("bidQtty01")),
        "Giá mua 2": pick_value(ba_data.get("bidPrice02")),
        "Khối lượng mua 2": pick_value(ba_data.get("bidQtty02")),
        "Giá mua 3": pick_value(ba_data.get("bidPrice03")),
        "Khối lượng mua 3": pick_value(ba_data.get("bidQtty03")),
        "Giá bán 1": pick_value(ba_data.get("offerPrice01")),
        "Khối lượng bán 1": pick_value(ba_data.get("offerQtty01")),
        "Giá bán 2": pick_value(ba_data.get("offerPrice02")),
        "Khối lượng bán 2": pick_value(ba_data.get("offerQtty02")),
        "Giá bán 3": pick_value(ba_data.get("offerPrice03")),
        "Khối lượng bán 3": pick_value(ba_data.get("offerQtty03")),
        "Giá khớp lệnh": pick_value(ba_data.get("matchPrice"), sp_data.get("currentPrice")),
        "Khối lượng khớp lệnh": pick_value(ba_data.get("matchQtty"), sp_data.get("currentQtty")),
        "Thời gian lấy dữ liệu": pick_value(ba_data.get("time"), sp_data.get("time"), fetched_at),
    }


def collect_realtime_rows(selected_codes):
    sp_map = {}
    ba_map = {}
    done = threading.Event()
    topics = [stock_topic(code) for code in selected_codes]
    topics += [transaction_topic(code) for code in selected_codes]

    def on_message(client, userdata, msg):
        try:
            payload = msg.payload.decode("utf-8", errors="replace")
            parsed = json.loads(payload)
        except Exception:
            return

        topic = msg.topic
        parts = topic.split("/")
        if len(parts) < 2:
            return

        if parts[0] == "T" and len(parts) >= 3:
            code = parts[2]
            if isinstance(parsed, dict):
                ba_map[code] = parsed
        else:
            code = parts[1]
            if isinstance(parsed, dict):
                sp_map[code] = parsed

        if all(code in sp_map and code in ba_map for code in selected_codes):
            done.set()

    client = create_client(topics)
    client.on_message = on_message
    client.connect_async("price-streaming-free.vndirect.com.vn", 443, keepalive=30)
    loop_thread = threading.Thread(target=client.loop_forever, daemon=True)
    loop_thread.start()

    if not client._userdata["connected"].wait(15):
        raise RuntimeError(
            "Khong ket noi duoc MQTT realtime cua VNDIRECT trong 15 giay."
        )

    done.wait(WAIT_TIMEOUT_SECONDS)
    client.disconnect()
    loop_thread.join(timeout=5)
    return sp_map, ba_map


def main():
    all_codes = load_stock_codes()
    selected_codes = select_codes(all_codes, sys.argv[1:])
    fetched_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    sp_map, ba_map = collect_realtime_rows(selected_codes)

    if not sp_map and not ba_map:
        raise SystemExit(
            "Khong nhan duoc ban tin realtime nao. Co the dang ngoai gio giao dich "
            "hoac feed free khong phat sinh du lieu cho cac ma vua chon."
        )

    normalized_rows = [
        merge_stock_data(code, sp_map.get(code), ba_map.get(code), fetched_at)
        for code in selected_codes
    ]
    content = "\n\n".join(
        format_block(index, record)
        for index, record in enumerate(normalized_rows, start=1)
    )
    OUTPUT_FILE.write_text(content + "\n", encoding="utf-8")

    print("Da chon 5 ma co phieu:")
    for code in selected_codes:
        print(f"- {code}")
    print(f"\nDa luu ket qua vao: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
