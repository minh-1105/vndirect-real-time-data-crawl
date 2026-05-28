import re


QUOTED_MESSAGE_RE = re.compile(r'"(.*?)"')


def decode_message(encoded_message):
    if not encoded_message:
        return []
    return [
        chr(ord(char) + (index % 5))
        for index, char in enumerate(encoded_message)
    ]


def decode_fields(encoded_message):
    return "".join(decode_message(encoded_message)).split("|")


def map_fields(field_names, values):
    return {
        field_name: values[index] if index < len(values) else None
        for index, field_name in enumerate(field_names)
    }


def parse_stock_message(message_type, values):
    stock_type = values[1] if len(values) > 1 else None

    if message_type == "SFU":
        if stock_type == "ST":
            fields = [
                "code", "stockType", "floorCode", "basicPrice", "floorPrice",
                "ceilingPrice", "bidPrice01", "bidPrice02", "bidPrice03",
                "bidPrice04", "bidPrice05", "bidPrice06", "bidPrice07",
                "bidPrice08", "bidPrice09", "bidPrice10", "bidQtty01",
                "bidQtty02", "bidQtty03", "bidQtty04", "bidQtty05",
                "bidQtty06", "bidQtty07", "bidQtty08", "bidQtty09",
                "bidQtty10", "offerPrice01", "offerPrice02", "offerPrice03",
                "offerPrice04", "offerPrice05", "offerPrice06", "offerPrice07",
                "offerPrice08", "offerPrice09", "offerPrice10", "offerQtty01",
                "offerQtty02", "offerQtty03", "offerQtty04", "offerQtty05",
                "offerQtty06", "offerQtty07", "offerQtty08", "offerQtty09",
                "offerQtty10", "totalBidQtty", "totalOfferQtty",
                "highestPrice", "lowestPrice", "accumulatedVal",
                "accumulatedVol", "matchPrice", "matchQtty", "currentPrice",
                "currentQtty", "totalRoom", "currentRoom", "iNav",
                "underlyingAsset", "issuer", "exercisePrice",
                "exerciseRatio", "expiryDate", "time", "bv4", "sv4",
            ]
        elif stock_type == "W":
            fields = [
                "code", "stockType", "floorCode", "basicPrice", "floorPrice",
                "ceilingPrice", "underlyingSymbol", "issuerName",
                "exercisePrice", "exerciseRatio", "bidPrice01", "bidPrice02",
                "bidPrice03", "bidQtty01", "bidQtty02", "bidQtty03",
                "offerPrice01", "offerPrice02", "offerPrice03", "offerQtty01",
                "offerQtty02", "offerQtty03", "totalBidQtty", "totalOfferQtty",
                "tradingSessionId", "buyForeignQtty", "sellForeignQtty",
                "highestPrice", "lowestPrice", "accumulatedVal",
                "accumulatedVol", "matchPrice", "matchQtty", "currentPrice",
                "currentQtty", "projectOpen", "totalRoom", "currentRoom",
            ]
        else:
            fields = [
                "code", "stockType", "floorCode", "basicPrice", "floorPrice",
                "ceilingPrice", "bidPrice01", "bidPrice02", "bidPrice03",
                "bidQtty01", "bidQtty02", "bidQtty03", "offerPrice01",
                "offerPrice02", "offerPrice03", "offerQtty01", "offerQtty02",
                "offerQtty03", "totalBidQtty", "totalOfferQtty",
                "tradingSessionId", "buyForeignQtty", "sellForeignQtty",
                "highestPrice", "lowestPrice", "accumulatedVal",
                "accumulatedVol", "matchPrice", "matchQtty", "currentPrice",
                "currentQtty", "projectOpen", "totalRoom", "currentRoom",
                "iNav",
            ]
        return map_fields(fields, values)

    if message_type == "SBA":
        if stock_type == "ST":
            fields = [
                "code", "stockType", "floorCode", "bidPrice01", "bidPrice02",
                "bidPrice03", "bidPrice04", "bidPrice05", "bidPrice06",
                "bidPrice07", "bidPrice08", "bidPrice09", "bidPrice10",
                "bidQtty01", "bidQtty02", "bidQtty03", "bidQtty04",
                "bidQtty05", "bidQtty06", "bidQtty07", "bidQtty08",
                "bidQtty09", "bidQtty10", "offerPrice01", "offerPrice02",
                "offerPrice03", "offerPrice04", "offerPrice05", "offerPrice06",
                "offerPrice07", "offerPrice08", "offerPrice09", "offerPrice10",
                "offerQtty01", "offerQtty02", "offerQtty03", "offerQtty04",
                "offerQtty05", "offerQtty06", "offerQtty07", "offerQtty08",
                "offerQtty09", "offerQtty10", "totalBidQtty", "totalOfferQtty",
            ]
        else:
            fields = [
                "code", "stockType", "floorCode", "bidPrice01", "bidPrice02",
                "bidPrice03", "bidQtty01", "bidQtty02", "bidQtty03",
                "offerPrice01", "offerPrice02", "offerPrice03", "offerQtty01",
                "offerQtty02", "offerQtty03", "totalBidQtty", "totalOfferQtty",
                "bv4", "sv4",
            ]
        return map_fields(fields, values)

    if message_type == "SMA":
        fields = [
            "code", "stockType", "floorCode", "buyForeignQtty",
            "sellForeignQtty", "highestPrice", "lowestPrice", "accumulatedVal",
            "accumulatedVol", "matchPrice", "matchQtty", "currentPrice",
            "currentQtty", "totalRoom", "currentRoom",
        ]
        return map_fields(fields, values)

    if message_type == "SBS":
        if stock_type == "W":
            fields = [
                "code", "stockType", "floorCode", "basicPrice", "floorPrice",
                "ceilingPrice", "underlyingSymbol", "issuerName",
                "exercisePrice", "exerciseRatio",
            ]
        else:
            fields = [
                "code", "stockType", "floorCode", "basicPrice", "floorPrice",
                "ceilingPrice",
            ]
        return map_fields(fields, values)

    return {"rawFields": values}


def parse_transaction_message(message_type, values):
    if message_type == "ST":
        fields = [
            "symbol", "time", "floorCode", "last", "lastVol",
            "accumulatedVol", "accumulatedVal",
        ]
        return map_fields(fields, values)
    return {"rawFields": values}


def parse_market_info_message(message_type, values):
    if message_type == "MI":
        fields = [
            "floorCode", "tradingTime", "status", "advance", "noChange",
            "decline", "marketIndex", "priorMarketIndex", "totalShareTraded",
            "totalValueTraded", "ceilingStock", "floorStock",
        ]
        return map_fields(fields, values)
    return {"rawFields": values}


def parse_payload(payload):
    if not isinstance(payload, str) or "|" not in payload or ":" not in payload:
        return None

    pipe_index = payload.index("|")
    colon_index = payload.index(":")
    room_name = payload[pipe_index + 1:colon_index]
    encoded_messages = QUOTED_MESSAGE_RE.findall(payload)

    decoded_messages = []
    for encoded_message in encoded_messages:
        values = decode_fields(encoded_message)
        if not values:
            continue

        message_type = values[0]
        body = values[1:]

        if room_name == "S":
            data = parse_stock_message(message_type, body)
        elif room_name == "ST":
            data = parse_transaction_message(message_type, body)
        elif room_name == "MI":
            data = parse_market_info_message(message_type, body)
        else:
            data = {"rawFields": body}

        decoded_messages.append({
            "roomName": room_name,
            "messageType": message_type,
            "data": data,
            "decodedFields": values,
        })

    return {
        "roomName": room_name,
        "messages": decoded_messages,
    }
