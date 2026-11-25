# syntax=docker/dockerfile:1

# ---------- Stage 1: build the Jitsi Meet web frontend ----------
FROM node:24-bookworm AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends git python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# postinstall (patch-package, android autolinking) needs the full source tree.
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

# `make all` = typecheck + webpack production build + copy assets into ./libs and build css/all.css
ENV NODE_OPTIONS=--max-old-space-size=6144
RUN make all

# Collect exactly what the jitsi-meet-web Debian package installs (see debian/jitsi-meet-web.install).
RUN mkdir -p /out/css /out/scripts \
 && cp -r *.html libs static sounds fonts images lang /out/ \
 && cp interface_config.js pwa-worker.js manifest.json /out/ \
 && cp css/all.css /out/css/ \
 && cp resources/robots.txt /out/

# Cache busting: the pages load the bundles with a fixed `?v=139` and the CSS with no version, so Cloudflare and
# browsers keep serving an old build for hours after a deploy. Stamp every page with a hash of this build instead.
RUN VER=$(cat /out/libs/app.bundle.min.js /out/css/all.css | sha256sum | cut -c1-12) \
 && find /out -maxdepth 2 -name '*.html' -exec sed -i \
      -e "s/?v=139\"/?v=${VER}\"/g" \
      -e "s#href=\"css/all.css\"#href=\"css/all.css?v=${VER}\"#g" {} + \
 && grep -q "app.bundle.min.js?v=${VER}" /out/index.html \
 && grep -q "css/all.css?v=${VER}" /out/index.html

# ---------- Stage 2: official jitsi/web image + our custom frontend ----------
# Keep this tag in sync with JITSI_TAG used for prosody/jicofo/jvb in docker-compose.yml.
# (Not an ARG on purpose: Coolify's Dockerfile mode injects ARGs and breaks ARG-before-FROM.)
FROM jitsi/web:stable

# config.js / interface_config.js are generated from env vars by the image at start-up (/config),
# so we only overlay the compiled frontend files.
COPY --from=build /out/ /usr/share/jitsi-meet/

# Course defaults (no camera button, muted start). Picked up by the image's /config handling.
COPY docker/custom-config.js /config/custom-config.js
# Geniuses branding (name, logo, welcome page switches); appended to the generated interface_config.js.
COPY docker/custom-interface_config.js /config/custom-interface_config.js
