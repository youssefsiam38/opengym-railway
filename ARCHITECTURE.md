# Architecture

```
Railway edge (HTTPS, public domain)
        │  :8080 ($PORT)
        ▼
┌──────────────────── opengym (one container) ────────────────────┐
│ nginx  — upstream web/nginx.conf.template, rendered at start     │
│   /            frontend (from the official opengym-web image)    │
│   /img /gif    → /storage/media (downloaded on first start)      │
│   /api/*       → 127.0.0.1:3000                                  │
│ node server.js — official opengym-api image, DATA_DIR=/storage/data
└──────────────────────────────┬───────────────────────────────────┘
                               ▼
                     volume /storage (data/, media/)
```

## Why one container

- Passkeys need the app and `/api` on one origin. Upstream does this with two containers (web/nginx + api) on a
  Docker network. On Railway, upstream's nginx block resolves the API with `ipv6=off` through a configurable
  resolver, while Railway's private network is IPv6-only; pointing nginx at loopback in the same container avoids
  the private network entirely.
- The exercise media is a shared volume between upstream's `media` job and `web`. Railway volumes attach to one
  service, so the download runs inside the same container.

## Start-up (`images/app/entrypoint.sh`)

1. Create `/storage/data` and `/storage/media/{img,gif}`; link the frontend's `img/` and `gif/` to them.
2. `railway-seed-owner.mjs` — when `db.json` holds no profiles, add one admin profile (`OWNER_NAME`, password hashed
   with openGym's own `hashPassword`, `admin: true`). Never touches an existing `db.json`.
3. Exercise media: unless `/storage/media/.complete` exists, stream the dataset tarball from GitHub in the background
   and extract `images/*.jpg` / `videos/*.gif`. The app is usable while it runs; a failed download is retried on the
   next start.
4. Render upstream's nginx server block with `BACKEND=127.0.0.1`, `PORT=3000`, `NGINX_PORT=$PORT`, add an IPv6
   listener, include it from `images/app/nginx.conf`.
5. Start the API (`PORT=3000`) and nginx; if either exits, the container exits and Railway restarts it.

## Client addresses

Railway's edge overwrites `X-Real-IP` with the visitor's address and `X-Forwarded-For` with "visitor, edge-hop",
discarding whatever the client sent (verified live). `nginx.conf` takes `X-Real-IP` as `$remote_addr`, and
upstream's server block then overwrites `X-Forwarded-For`/`X-Real-IP` towards the API with it. With `TRUST_PROXY=1`
the API's sign-in throttle and activity log count real visitors rather than the edge.
