# Railway / GHCR: CF + WS VLESS → HTTP 代理

把现有 VLESS（尤其 Cloudflare + WebSocket + TLS）转成带账号密码的 HTTP 代理。

## 镜像（GHCR）

GitHub Actions 会自动构建并推送到：

```text
ghcr.io/<你的GitHub用户名>/railway-http:latest
```

如果仓库名是 `ytjvhmgv/railway-http`，则镜像为：

```text
ghcr.io/ytjvhmgv/railway-http:latest
ghcr.io/ytjvhmgv/railway-http:sha-<commit>
```

> GHCR 镜像名必须小写。

### 手动触发

GitHub 仓库 → **Actions** → **Build and Push GHCR** → **Run workflow**

### 本地拉取

公开包：

```bash
docker pull ghcr.io/ytjvhmgv/railway-http:latest
```

如果是 Private package，先登录：

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/ytjvhmgv/railway-http:latest
```

### 本地运行

```bash
docker run --rm -p 8080:8080 \
  -e PROXY_USER=myuser \
  -e PROXY_PASS=strong-password \
  -e VLESS_LINK='vless://....' \
  ghcr.io/ytjvhmgv/railway-http:latest
```

## Railway 部署方式

### A. 继续用 Dockerfile（现有方式）

连 GitHub 仓库，Railway 本地构建。

### B. 直接用 GHCR 镜像

1. 先等 Actions 推送成功
2. Railway → New → **Docker Image**
3. 填：`ghcr.io/ytjvhmgv/railway-http:latest`
4. 若私有镜像，加 registry 凭证
5. Variables：

```text
PROXY_USER=myuser
PROXY_PASS=强密码
VLESS_LINK=vless://...
```

6. TCP Proxy 端口：`8080`

## 环境变量

| 变量 | 必填 | 说明 |
|---|---|---|
| `PROXY_USER` | 是 | HTTP 代理用户名 |
| `PROXY_PASS` | 是 | HTTP 代理密码 |
| `VLESS_LINK` | 推荐 | 完整 VLESS 分享链接 |
| `PORT` | 否 | 默认 8080 |
| `VLESS_FINGERPRINT` | 否 | 覆盖链接中的 fp，如 chrome/firefox/random |

## GitHub Package 可见性

首次推送后：

1. GitHub 仓库右侧 **Packages**
2. 点进 `railway-http`
3. **Package settings** → Danger Zone / Influence
4. 可改成 **Public**（方便 Railway 免登录拉取）

## 工作流文件

- `.github/workflows/docker-publish.yml`
  - push 到 main/master 自动构建
  - tag `v*` 打版本号
  - PR 只构建不推送
  - 支持 `workflow_dispatch` 手动构建
  - 多架构：`linux/amd64,linux/arm64`
