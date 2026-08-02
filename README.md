# Railway: CF + WS VLESS → HTTP 代理

专门适配 Cloudflare IP + WebSocket + TLS 节点。

## 最快配置

```text
PROXY_USER=myuser
PROXY_PASS=强密码
VLESS_LINK=vless://你的完整分享链接
```

## CF+WS 适配点

1. 支持 `VLESS_LINK` 一键粘贴
2. path 自动 URL 解码（保留 `/proxyip=IP:PORT`）
3. 不强制 ALPN
4. `address=CF IP`，`sni/host=域名`
5. 钉选 Xray v25.3.6
6. 避免默认 env 覆盖 link 中的 path/fp

## 测试

```bash
curl -x http://myuser:密码@xxx.up.railway.app:443 https://ip.sb
```

握手失败时只改：

```text
VLESS_FINGERPRINT=chrome|firefox|random
```
