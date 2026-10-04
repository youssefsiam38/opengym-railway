# syntax=docker/dockerfile:1
#
# Combined image for the openGym Railway template: openGym's official API image with the official
# web image's built frontend and nginx config in the same container. Railway gives a template one
# public origin per service, and passkeys need the app and /api on that one origin, so nginx (the
# public listener on $PORT) serves the frontend and proxies /api to the API on loopback. openGym's
# own code is unmodified; the wrapper adds the entrypoint, an owner seed and the media download.
ARG OPENGYM_API_IMAGE=ghcr.io/duartesantos8/opengym-api:1.3.9@sha256:e0232eb55bc193f9d3c6938105e6202114eb02d1dd2a9c2476c7e486435e9aab
ARG OPENGYM_WEB_IMAGE=ghcr.io/duartesantos8/opengym-web:1.3.9@sha256:9d19807f28a59a449b26a009f96764fc93fc6ea78b139891ee2010146d7ea792

FROM ${OPENGYM_WEB_IMAGE} AS web

FROM ${OPENGYM_API_IMAGE}
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

# nginx serves the app (the same server block upstream's web image renders), gettext provides
# envsubst to render it, curl fetches the exercise media on first start.
RUN apk add --no-cache nginx gettext curl

COPY --from=web /usr/share/nginx/html /usr/share/nginx/html
COPY --from=web /etc/nginx/templates/default.conf.template /etc/opengym/default.conf.template
COPY images/app/nginx.conf /etc/opengym/nginx.conf
COPY images/app/seed-owner.mjs /app/railway-seed-owner.mjs
COPY --chmod=0755 images/app/entrypoint.sh /usr/local/bin/opengym-entrypoint

# Everything persistent lives on one Railway volume mounted at /storage:
#   /storage/data   the API's DATA_DIR (db.json, per-profile state, session secret, uploads)
#   /storage/media  the exercise images and GIFs downloaded on first start
ENV STORAGE_DIR=/storage \
    DATA_DIR=/storage/data \
    API_PORT=3000 \
    PORT=8080

LABEL org.opencontainers.image.title="opengym-railway" \
      org.opencontainers.image.description="openGym (API + web in one container) for the openGym Railway template. Not affiliated with the openGym project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/opengym-railway" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later AND MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}"

HEALTHCHECK NONE
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/opengym-entrypoint"]
CMD []
