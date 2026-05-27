import json
import socket
import threading
import time

import paho.mqtt.client as mqtt


MQTT_HOST = "price-streaming-free.vndirect.com.vn"
MQTT_PORT = 443
MQTT_PATH = "/mqtt"
MQTT_USERNAME = "1d84f25b561f2575"

MARKET_INFO_TOPICS = [
    "MI/10",
    "MI/02",
    "MI/03",
    "MI/11",
    "MI/12",
    "MI/13",
    "MI/VN100",
    "MI/VNDIAMOND",
    "MI/VN30",
    "MI/DER01",
]


def stock_topic(symbol, floor_code="+"):
    return f"{floor_code}/{symbol.upper()}"


def transaction_topic(symbol, floor_code="+"):
    return f"T/{floor_code}/{symbol.upper()}"


def create_client(topics):
    userdata = {"topics": topics, "connected": threading.Event()}
    client_id = f"free-user-python-{int(time.time())}"
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION2,
        client_id=client_id,
        userdata=userdata,
        protocol=mqtt.MQTTv5,
        transport="websockets",
    )
    client.username_pw_set(MQTT_USERNAME)
    client.ws_set_options(path=MQTT_PATH)
    client.tls_set()
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect
    return client


def on_connect(client, userdata, flags, reason_code, properties=None):
    print(f"Connected: {reason_code}")
    userdata["connected"].set()
    subscriptions = [(topic, 0) for topic in userdata["topics"]]
    client.subscribe(subscriptions)
    print("Subscribed:", ", ".join(userdata["topics"]))


def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8", errors="replace")
    try:
        payload = json.dumps(json.loads(payload), ensure_ascii=False)
    except json.JSONDecodeError:
        pass
    print(f"{msg.topic}: {payload}")


def on_disconnect(client, userdata, disconnect_flags, reason_code, properties=None):
    print(f"Disconnected: {reason_code}")


def run(symbols=None, floor_code="+", include_market_info=True):
    symbols = symbols or ["VND", "AAA"]
    topics = [stock_topic(symbol, floor_code) for symbol in symbols]
    topics += [transaction_topic(symbol, floor_code) for symbol in symbols]
    if include_market_info:
        topics += MARKET_INFO_TOPICS

    try:
        with socket.create_connection((MQTT_HOST, MQTT_PORT), timeout=10):
            pass
    except OSError as exc:
        print(f"Cannot open TCP connection to {MQTT_HOST}:{MQTT_PORT}: {exc}")
        print("Check firewall/network access to VNDIRECT price-streaming websocket.")
        return

    client = create_client(topics)
    connected = False
    try:
        socket.setdefaulttimeout(10)
        client.connect_async(MQTT_HOST, MQTT_PORT, keepalive=30)
        loop_thread = threading.Thread(target=client.loop_forever, daemon=True)
        loop_thread.start()
        if not client._userdata["connected"].wait(15):
            print(f"Cannot connect to {MQTT_HOST}:{MQTT_PORT} within 15 seconds.", flush=True)
            print("Check firewall/network access to VNDIRECT price-streaming websocket.", flush=True)
            return
        connected = True
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopped.")
    except OSError as exc:
        print(f"Cannot connect to {MQTT_HOST}:{MQTT_PORT}: {exc}")
        print("Check firewall/network access to VNDIRECT price-streaming websocket.")
    finally:
        if connected:
            client.disconnect()
