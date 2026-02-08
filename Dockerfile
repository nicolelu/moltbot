FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install chromium and dependencies for browser automation
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      chromium curl ca-certificates jq && \
    npx playwright install-deps chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy gog safety wrapper (blocks email sending, allows drafts + calendar)
COPY scripts/gog-wrapper.sh /tmp/gog-wrapper.sh

# Install gog and goplaces CLI tools from GitHub releases
RUN set -eux; \
  install_gh_release_bin() { \
    repo="$1"; \
    bin="$2"; \
    pattern="$3"; \
    api="https://api.github.com/repos/${repo}/releases/latest"; \
    url="$(curl -fsSL "$api" | jq -r --arg re "$pattern" '.assets[] | select(.name|test($re)) | .browser_download_url' | head -n 1)"; \
    test -n "$url"; \
    tmp="/tmp/${bin}.asset"; \
    curl -fsSL "$url" -o "$tmp"; \
    case "$url" in \
      *.tar.gz|*.tgz) tar -xzf "$tmp" -C /usr/local/bin ;; \
      *.zip) mkdir -p "/tmp/${bin}_unz" && unzip -q "$tmp" -d "/tmp/${bin}_unz" && \
             found="$(find "/tmp/${bin}_unz" -type f -name "$bin" | head -n 1)" && \
             mv "$found" "/usr/local/bin/$bin" ;; \
      *) mv "$tmp" "/usr/local/bin/$bin"; tmp="" ;; \
    esac; \
    chmod +x "/usr/local/bin/$bin"; \
    rm -rf "$tmp" "/tmp/${bin}_unz" || true; \
  }; \
  install_gh_release_bin "steipete/gogcli" "gog" "linux_amd64"; \
  install_gh_release_bin "steipete/goplaces" "goplaces" "linux.*(x86_64|amd64)"; \
  # Safety wrapper: rename real gog and install wrapper that blocks email sending \
  mv /usr/local/bin/gog /usr/local/bin/gog-real; \
  cp /tmp/gog-wrapper.sh /usr/local/bin/gog; \
  chmod +x /usr/local/bin/gog

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Allow non-root user to write temp files during runtime/tests.
RUN chown -R node:node /app

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges
USER node

# Start gateway server with default config.
# Binds to loopback (127.0.0.1) by default for security.
#
# For container platforms requiring external health checks:
#   1. Set OPENCLAW_GATEWAY_TOKEN or OPENCLAW_GATEWAY_PASSWORD env var
#   2. Override CMD: ["node","openclaw.mjs","gateway","--allow-unconfigured","--bind","lan"]
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
