import json
import urllib.parse
import urllib.request


SNAPSHOT_URL = "https://price-streaming-api.vndirect.com.vn/v2/stocks/snapshot"


def get_snapshot(symbols):
    query = urllib.parse.urlencode({"codes": ",".join(symbols)})
    request = urllib.request.Request(
        f"{SNAPSHOT_URL}?{query}",
        headers={"User-Agent": "python-vndirect-snapshot/1.0"},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def main(symbols):
    data = get_snapshot(symbols)
    for symbol, row in zip(symbols, data):
        print(f"{symbol}: {row}")

