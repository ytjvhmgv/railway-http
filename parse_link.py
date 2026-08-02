#!/usr/bin/env python3
import json, sys
from urllib.parse import unquote, parse_qs

def as_bool(v, default=False):
    if v is None or v == "":
        return default
    return str(v).strip().lower() in ("1", "true", "yes", "on")

def first(qs, *keys, default=""):
    for k in keys:
        vals = qs.get(k)
        if vals and vals[0] != "":
            return vals[0]
    return default

def parse_vless_link(link: str) -> dict:
    raw = link.strip()
    if raw.startswith("vless://"):
        raw = raw[len("vless://"):]
    if "#" in raw:
        raw, _ = raw.split("#", 1)
    if "?" in raw:
        main, query = raw.split("?", 1)
        qs = parse_qs(query, keep_blank_values=True)
    else:
        main, qs = raw, {}
    uuid, server_part = main.split("@", 1)
    server, port_s = server_part.rsplit(":", 1)
    path = unquote(first(qs, "path", default="/"))
    if path and not path.startswith("/"):
        path = "/" + path
    return {
        "uuid": unquote(uuid),
        "server": unquote(server),
        "port": int(port_s),
        "network": first(qs, "type", "network", default="ws").lower(),
        "security": first(qs, "security", default="tls").lower(),
        "sni": first(qs, "sni", "serverName", "peer", default=""),
        "host": first(qs, "host", "Host", default=""),
        "path": path or "/",
        "fingerprint": first(qs, "fp", "fingerprint", default="chrome"),
        "allow_insecure": as_bool(first(qs, "allowInsecure", "insecure", default="0"), False),
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python parse_link.py 'vless://...'")
        raise SystemExit(1)
    print(json.dumps(parse_vless_link(sys.argv[1]), ensure_ascii=False, indent=2))
