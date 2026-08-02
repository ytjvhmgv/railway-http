#!/bin/sh
set -eu

export PORT="${PORT:-8080}"
export PROXY_USER="${PROXY_USER:-proxyuser}"
export PROXY_PASS="${PROXY_PASS:-changeme}"
export LOG_LEVEL="${LOG_LEVEL:-warning}"
export VLESS_LINK="${VLESS_LINK:-}"

# When VLESS_LINK is set, do NOT inject defaults for path/fp/network/etc.
# Otherwise Dockerfile/env defaults clobber share-link values.
if [ -z "$VLESS_LINK" ]; then
  export VLESS_UUID="${VLESS_UUID:-}"
  export VLESS_SERVER="${VLESS_SERVER:-}"
  export VLESS_PORT="${VLESS_PORT:-}"
  export VLESS_NETWORK="${VLESS_NETWORK:-ws}"
  export VLESS_SECURITY="${VLESS_SECURITY:-tls}"
  export VLESS_SNI="${VLESS_SNI:-}"
  export VLESS_HOST="${VLESS_HOST:-}"
  export VLESS_PATH="${VLESS_PATH:-/}"
  export VLESS_FLOW="${VLESS_FLOW:-}"
  export VLESS_FINGERPRINT="${VLESS_FINGERPRINT:-chrome}"
  export VLESS_ALPN="${VLESS_ALPN:-}"
  export VLESS_ALLOW_INSECURE="${VLESS_ALLOW_INSECURE:-false}"
  export VLESS_PUBLIC_KEY="${VLESS_PUBLIC_KEY:-}"
  export VLESS_SHORT_ID="${VLESS_SHORT_ID:-}"
  export VLESS_SPIDER_X="${VLESS_SPIDER_X:-}"
  export VLESS_GRPC_SERVICE_NAME="${VLESS_GRPC_SERVICE_NAME:-}"
fi

if [ "$PROXY_PASS" = "changeme" ]; then
  echo "WARNING: PROXY_PASS is still the default value. Set a strong password." >&2
fi

python3 - <<'PY'
import json, os, sys
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

def env(name, default=""):
    return (os.environ.get(name) or default).strip()

def parse_vless_link(link: str) -> dict:
    raw = link.strip()
    if raw.startswith("vless://"):
        raw = raw[len("vless://"):]
    if "#" in raw:
        raw, _name = raw.split("#", 1)
    if "?" in raw:
        main, query = raw.split("?", 1)
        qs = parse_qs(query, keep_blank_values=True)
    else:
        main, qs = raw, {}
    if "@" not in main:
        raise ValueError("VLESS link missing @server part")
    uuid, server_part = main.split("@", 1)
    if ":" not in server_part:
        raise ValueError("VLESS link missing server port")
    server, port_s = server_part.rsplit(":", 1)

    path = unquote(first(qs, "path", default="/"))
    if path and not path.startswith("/"):
        path = "/" + path

    return {
        "uuid": unquote(uuid),
        "server": unquote(server),
        "port": int(port_s),
        "network": (first(qs, "type", "network", default="ws") or "ws").lower(),
        "security": (first(qs, "security", default="tls") or "tls").lower(),
        "sni": first(qs, "sni", "serverName", "peer", default=""),
        "host": first(qs, "host", "Host", default=""),
        "path": path or "/",
        "fingerprint": first(qs, "fp", "fingerprint", default="chrome") or "chrome",
        "flow": first(qs, "flow", default=""),
        "alpn": first(qs, "alpn", default=""),
        "allow_insecure": as_bool(first(qs, "allowInsecure", "insecure", default="0"), False),
        "public_key": first(qs, "pbk", "publicKey", default=""),
        "short_id": first(qs, "sid", "shortId", default=""),
        "spider_x": first(qs, "spx", "spiderX", default="/") or "/",
        "grpc_service": first(qs, "serviceName", default=""),
    }

link = env("VLESS_LINK")
if link:
    try:
        cfg = parse_vless_link(link)
    except Exception as e:
        print(f"Failed to parse VLESS_LINK: {e}", file=sys.stderr)
        sys.exit(1)

    mapping = {
        "uuid": "VLESS_UUID",
        "server": "VLESS_SERVER",
        "port": "VLESS_PORT",
        "network": "VLESS_NETWORK",
        "security": "VLESS_SECURITY",
        "sni": "VLESS_SNI",
        "host": "VLESS_HOST",
        "path": "VLESS_PATH",
        "fingerprint": "VLESS_FINGERPRINT",
        "flow": "VLESS_FLOW",
        "alpn": "VLESS_ALPN",
        "public_key": "VLESS_PUBLIC_KEY",
        "short_id": "VLESS_SHORT_ID",
        "spider_x": "VLESS_SPIDER_X",
        "grpc_service": "VLESS_GRPC_SERVICE_NAME",
    }
    for key, env_name in mapping.items():
        val = env(env_name)
        if val != "":
            cfg[key] = val
    if env("VLESS_ALLOW_INSECURE") != "":
        cfg["allow_insecure"] = as_bool(env("VLESS_ALLOW_INSECURE"), False)
else:
    cfg = {
        "uuid": env("VLESS_UUID"),
        "server": env("VLESS_SERVER"),
        "port": env("VLESS_PORT"),
        "network": env("VLESS_NETWORK", "ws").lower() or "ws",
        "security": env("VLESS_SECURITY", "tls").lower() or "tls",
        "sni": env("VLESS_SNI"),
        "host": env("VLESS_HOST"),
        "path": env("VLESS_PATH", "/") or "/",
        "fingerprint": env("VLESS_FINGERPRINT", "chrome") or "chrome",
        "flow": env("VLESS_FLOW"),
        "alpn": env("VLESS_ALPN"),
        "allow_insecure": as_bool(env("VLESS_ALLOW_INSECURE"), False),
        "public_key": env("VLESS_PUBLIC_KEY"),
        "short_id": env("VLESS_SHORT_ID"),
        "spider_x": env("VLESS_SPIDER_X") or "/",
        "grpc_service": env("VLESS_GRPC_SERVICE_NAME"),
    }

if isinstance(cfg.get("port"), str):
    if not cfg["port"]:
        print("VLESS_PORT or port in VLESS_LINK is required", file=sys.stderr)
        sys.exit(1)
    cfg["port"] = int(cfg["port"])

cfg["path"] = unquote(str(cfg.get("path") or "/"))
if cfg["path"] and not str(cfg["path"]).startswith("/"):
    cfg["path"] = "/" + cfg["path"]

if not cfg.get("sni"):
    cfg["sni"] = cfg.get("host") or cfg.get("server") or ""
if not cfg.get("host"):
    cfg["host"] = cfg.get("sni") or cfg.get("server") or ""

if not cfg.get("uuid") or not cfg.get("server") or not cfg.get("port"):
    print("VLESS_UUID/VLESS_SERVER/VLESS_PORT are required (or provide VLESS_LINK)", file=sys.stderr)
    sys.exit(1)

listen_port = int(os.environ.get("PORT", "8080"))
proxy_user = os.environ["PROXY_USER"]
proxy_pass = os.environ["PROXY_PASS"]

uuid = cfg["uuid"]
server = cfg["server"]
server_port = int(cfg["port"])
network = (cfg.get("network") or "ws").lower()
security = (cfg.get("security") or "tls").lower()
sni = cfg.get("sni") or server
host = cfg.get("host") or sni
req_path = cfg.get("path") or "/"
flow = cfg.get("flow") or ""
fingerprint = (cfg.get("fingerprint") or "chrome").lower()
alpn_raw = cfg.get("alpn") or ""
allow_insecure = bool(cfg.get("allow_insecure"))
public_key = cfg.get("public_key") or ""
short_id = cfg.get("short_id") or ""
spider_x = cfg.get("spider_x") or "/"
grpc_service = cfg.get("grpc_service") or ""

looks_like_ip = all((c.isdigit() or c == ".") for c in server)
if network == "ws" and security == "tls" and looks_like_ip and (not sni or sni == server):
    print("WARNING: CF-like IP server but SNI empty/same as IP. Set VLESS_SNI to your domain.", file=sys.stderr)
if network == "ws" and "proxyip=" in req_path:
    print(f"CF worker-style path detected: {req_path}")

user = {"id": uuid, "encryption": "none"}
if flow:
    user["flow"] = flow

stream = {
    "network": network,
    "security": security if security in ("tls", "reality") else "none",
}

if network == "ws":
    stream["wsSettings"] = {
        "path": req_path,
        "headers": {"Host": host},
    }
elif network == "grpc":
    stream["grpcSettings"] = {
        "serviceName": grpc_service or req_path.strip("/"),
        "multiMode": False,
    }
elif network == "tcp":
    stream["tcpSettings"] = {}
else:
    print(f"Unsupported VLESS_NETWORK: {network}", file=sys.stderr)
    sys.exit(1)

if security == "tls":
    tls = {
        "serverName": sni,
        "allowInsecure": allow_insecure,
        "fingerprint": fingerprint,
    }
    if alpn_raw.strip():
        tls["alpn"] = [x.strip() for x in alpn_raw.replace(";", ",").split(",") if x.strip()]
    stream["tlsSettings"] = tls
elif security == "reality":
    if not public_key:
        print("VLESS_PUBLIC_KEY is required for reality", file=sys.stderr)
        sys.exit(1)
    stream["realitySettings"] = {
        "serverName": sni,
        "fingerprint": fingerprint,
        "publicKey": public_key,
        "shortId": short_id,
        "spiderX": spider_x or "/",
    }

config = {
    "log": {"loglevel": os.environ.get("LOG_LEVEL", "warning")},
    "inbounds": [
        {
            "tag": "http-in",
            "listen": "0.0.0.0",
            "port": listen_port,
            "protocol": "http",
            "settings": {
                "accounts": [{"user": proxy_user, "pass": proxy_pass}],
                "allowTransparent": False,
            },
            "sniffing": {
                "enabled": True,
                "destOverride": ["http", "tls", "quic"],
                "routeOnly": True,
            },
        }
    ],
    "outbounds": [
        {
            "tag": "vless-out",
            "protocol": "vless",
            "settings": {
                "vnext": [{
                    "address": server,
                    "port": server_port,
                    "users": [user],
                }]
            },
            "streamSettings": stream,
        },
        {"tag": "direct", "protocol": "freedom"},
        {"tag": "block", "protocol": "blackhole"},
    ],
}

with open("/tmp/xray-config.json", "w", encoding="utf-8") as f:
    json.dump(config, f, ensure_ascii=False, indent=2)

print(f"HTTP proxy listening on 0.0.0.0:{listen_port}")
print(
    "Upstream VLESS: "
    f"{server}:{server_port} network={network} security={security} "
    f"sni={sni} host={host} path={req_path} fp={fingerprint} allowInsecure={allow_insecure}"
)
print("Tip: CF+WS handshake fail -> try VLESS_FINGERPRINT=chrome|firefox|random")

PY

exec xray -config /tmp/xray-config.json
