# Upstream

| | |
|---|---|
| Project | https://github.com/DuarteSantos8/openGym (AGPL-3.0) |
| Release | v1.3.9 (2026-09-28) |
| API image | `ghcr.io/duartesantos8/opengym-api:1.3.9@sha256:e0232eb55bc193f9d3c6938105e6202114eb02d1dd2a9c2476c7e486435e9aab` |
| Web image | `ghcr.io/duartesantos8/opengym-web:1.3.9@sha256:9d19807f28a59a449b26a009f96764fc93fc6ea78b139891ee2010146d7ea792` |
| Exercise media | https://github.com/hasaneyldrm/exercises-dataset (`main`, fetched at run time) |

Get new digests:

```bash
docker buildx imagetools inspect ghcr.io/duartesantos8/opengym-api:<version>
docker buildx imagetools inspect ghcr.io/duartesantos8/opengym-web:<version>
```

What the wrapper relies on (re-check on every bump):

- `api/password.js` exports `hashPassword` and `passwordProblem`; users in `db.json` with `pw.h` sign in by name
  when `PASSWORD_LOGIN` is on; `user.admin === true` makes an admin.
- The web image keeps its frontend at `/usr/share/nginx/html` and its template at
  `/etc/nginx/templates/default.conf.template`, with the `NGINX_PORT`/`BACKEND`/`PORT`/`RESOLVER`/
  `CF_CONNECTING_IP`/`BASE_PATH`/`MEDIA_UPLOAD_MAX` placeholders.
- The frontend loads exercise media from relative `img/` and `gif/`.
