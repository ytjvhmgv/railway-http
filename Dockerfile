FROM alpine:3.20

# Pin stable Xray for CF/WS/uTLS compatibility.
ARG XRAY_VERSION=25.3.6
RUN apk add --no-cache ca-certificates curl unzip python3 \
  && update-ca-certificates \
  && arch="$(uname -m)" \
  && case "$arch" in \
      x86_64) xray_arch=64 ;; \
      aarch64) xray_arch=arm64-v8a ;; \
      armv7l) xray_arch=arm32-v7a ;; \
      *) echo "unsupported arch: $arch" && exit 1 ;; \
    esac \
  && curl -fsSL "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${xray_arch}.zip" -o /tmp/xray.zip \
  && unzip -q /tmp/xray.zip xray -d /usr/local/bin \
  && chmod +x /usr/local/bin/xray \
  && rm -f /tmp/xray.zip \
  && xray version

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Do not default VLESS_PATH/FINGERPRINT here; they would clobber VLESS_LINK parsing.
ENV PORT=8080 \
    PROXY_USER=proxyuser \
    PROXY_PASS=changeme \
    LOG_LEVEL=warning

EXPOSE 8080
CMD ["/app/entrypoint.sh"]
