#!/bin/sh
# Entrypoint for the openGym Railway template.
# shellcheck disable=SC2012,SC2016,SC2317
#
#   1. lays out the /storage volume (data/ for the API, media/ for exercise images and GIFs)
#   2. seeds the owner profile on first boot (seed-owner.mjs; never prints the password)
#   3. starts openGym's API on $API_PORT (only nginx calls it) and nginx on the public $PORT
#   4. downloads the exercise media in the background on first start, as upstream's compose does
#
# If either process exits, the container exits so Railway restarts it.
set -eu

log() { printf '[opengym-railway] %s\n' "$*"; }
die() { printf '[opengym-railway] ERROR: %s\n' "$*" >&2; exit 1; }

STORAGE_DIR=${STORAGE_DIR:-/storage}
DATA_DIR=${DATA_DIR:-$STORAGE_DIR/data}
MEDIA_DIR=$STORAGE_DIR/media
API_PORT=${API_PORT:-3000}
PUBLIC_PORT=${PORT:-8080}
EXERCISE_MEDIA=${EXERCISE_MEDIA:-download}
MEDIA_SOURCE_URL=${MEDIA_SOURCE_URL:-https://codeload.github.com/hasaneyldrm/exercises-dataset/tar.gz/refs/heads/main}

[ "$API_PORT" != "$PUBLIC_PORT" ] || die "API_PORT and PORT must differ (API on loopback, nginx public)."
[ -n "${ORIGIN:-}" ] || die "ORIGIN is not set (e.g. https://your-app.up.railway.app)."
[ -n "${RP_ID:-}" ] || die "RP_ID is not set (the hostname passkeys are bound to)."

mkdir -p "$DATA_DIR" "$MEDIA_DIR/img" "$MEDIA_DIR/gif" /tmp/opengym
export DATA_DIR

# --- owner ------------------------------------------------------------------------------------
cd /app
if [ -n "${OWNER_PASSWORD:-}" ]; then
  node /app/railway-seed-owner.mjs
else
  log "OWNER_PASSWORD is empty: no owner is seeded (anyone with an invite, or open sign-up if INVITE_ONLY is off, creates the first profile)"
fi

# --- exercise media ---------------------------------------------------------------------------
# Served from the volume through the frontend's img/ and gif/ paths.
for d in img gif; do
  rm -rf "/usr/share/nginx/html/$d"
  ln -s "$MEDIA_DIR/$d" "/usr/share/nginx/html/$d"
done

fetch_media() {
  # Same source as upstream's compose `media` service: github.com/hasaneyldrm/exercises-dataset.
  # Images and animations are third-party content (see openGym's NOTICE.md); they are downloaded
  # by this instance from that source, never shipped in the image.
  log "downloading exercise media (~140 MB, one time) from github.com/hasaneyldrm/exercises-dataset"
  log "  images and animations are third-party content, not covered by openGym's AGPL; see openGym's NOTICE.md"
  tmp="$STORAGE_DIR/.media-incoming"
  rm -rf "$tmp"; mkdir -p "$tmp"
  if curl -fsSL --retry 5 --retry-delay 5 --connect-timeout 20 "$MEDIA_SOURCE_URL" \
       | tar xz -C "$tmp" exercises-dataset-main/images exercises-dataset-main/videos; then
    # Copy into the live dirs (the nginx symlinks point at them), then mark complete.
    cp "$tmp"/exercises-dataset-main/images/*.jpg "$MEDIA_DIR/img/"
    cp "$tmp"/exercises-dataset-main/videos/*.gif "$MEDIA_DIR/gif/"
    rm -rf "$tmp"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$MEDIA_DIR/.complete"
    log "exercise media ready ($(ls "$MEDIA_DIR/img" | wc -l) images, $(ls "$MEDIA_DIR/gif" | wc -l) animations)"
  else
    rm -rf "$tmp"
    log "WARNING: exercise media download failed; the app works without it and retries on the next restart"
  fi
}

case "$EXERCISE_MEDIA" in
  download)
    if [ -f "$MEDIA_DIR/.complete" ]; then
      log "exercise media already present ($(ls "$MEDIA_DIR/img" | wc -l) images)"
    else
      fetch_media &
    fi ;;
  off|0|false|no) log "EXERCISE_MEDIA=off: exercise images and animations are not downloaded" ;;
  *) die "EXERCISE_MEDIA must be 'download' or 'off' (got '$EXERCISE_MEDIA')" ;;
esac

# --- nginx (upstream's server block, pointed at the API on loopback) ---------------------------
NGINX_PORT=$PUBLIC_PORT BACKEND=127.0.0.1 PORT=$API_PORT RESOLVER=127.0.0.1 \
CF_CONNECTING_IP=${CF_CONNECTING_IP:-} BASE_PATH=${BASE_PATH:-} MEDIA_UPLOAD_MAX=${MEDIA_UPLOAD_MAX:-48m} \
  envsubst '${NGINX_PORT} ${BACKEND} ${PORT} ${RESOLVER} ${CF_CONNECTING_IP} ${BASE_PATH} ${MEDIA_UPLOAD_MAX}' \
  < /etc/opengym/default.conf.template > /tmp/opengym/default.conf
# Railway's private network and health checks may use IPv6: listen on both stacks.
sed -i "s|^\(\s*\)listen ${PUBLIC_PORT};|\1listen ${PUBLIC_PORT};\n\1listen [::]:${PUBLIC_PORT};|" /tmp/opengym/default.conf
nginx -t -c /etc/opengym/nginx.conf -q

# --- processes --------------------------------------------------------------------------------
log "starting openGym API on :${API_PORT} (reached through nginx; not routed publicly)"
PORT=$API_PORT node server.js &
API_PID=$!

log "starting nginx on :${PUBLIC_PORT} (origin ${ORIGIN})"
nginx -c /etc/opengym/nginx.conf -g 'daemon off;' &
NGINX_PID=$!

stop() { kill -TERM "$API_PID" "$NGINX_PID" 2>/dev/null || true; wait "$API_PID" 2>/dev/null || true; wait "$NGINX_PID" 2>/dev/null || true; exit 0; }
trap stop TERM INT

while kill -0 "$API_PID" 2>/dev/null && kill -0 "$NGINX_PID" 2>/dev/null; do sleep 2; done
log "a process exited; stopping the container"
kill -TERM "$API_PID" "$NGINX_PID" 2>/dev/null || true
exit 1
