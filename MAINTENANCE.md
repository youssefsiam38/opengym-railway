# Maintenance

## Updating to a new openGym release

1. **Bump both pins** in `images/app/Dockerfile` (`OPENGYM_API_IMAGE`, `OPENGYM_WEB_IMAGE`) to the same release, by
   digest (see `UPSTREAM.md`), and re-check the contracts listed there.
2. **Run the tests locally:**
   ```bash
   tests/static.sh
   docker compose build --pull
   tests/smoke.sh
   tests/persistence.sh
   ```
3. **Tag** (`git tag vX.Y.Z && git push --tags`). `publish-image.yml` re-runs the tests and pushes
   `ghcr.io/youssefsiam38/opengym-railway:X.Y.Z`.
4. **Re-point the template** (`_audit/spec_opengym.py` `WRAPPER_TAG`, then `tplkit.patch_template`), deploy it into a
   scratch project and run `tests/railway-smoke.sh`, including a redeploy, before updating the published template.

## Rebuilding the Railway template from scratch

`RAILWAY_TEMPLATE.md` has the exact configuration; `_audit/spec_opengym.py` + `_audit/tplkit.py` build a skeleton,
create and patch the template. Volumes, domains and health checks are set only by `skeleton()`.

## Gotchas

- **`PORT` is nginx's.** Railway routes the domain and health check to `PORT` (8080). The API gets `PORT=$API_PORT`
  (3000) from the entrypoint, so the two never collide.
- **Owner seed runs once.** Only when `db.json` has no profiles. It refuses to touch an unreadable `db.json`.
- **Passkeys follow `RP_ID`.** A domain rename does not redeploy on Railway; `RP_ID`/`ORIGIN` referencing
  `RAILWAY_PUBLIC_DOMAIN` only pick up the new name on the next deploy, and passkeys made on the old name stop
  working. Password sign-in keeps the owner able to get in.
- **Media download** streams `codeload.github.com/.../tar.gz/refs/heads/main` and extracts `exercises-dataset-main/
  {images,videos}`; if upstream renames the branch or folders, update `MEDIA_SOURCE_URL`/the tar paths.
- **Local tests** use `RP_ID=localhost` and `ORIGIN=http://localhost:18080`, but curl hits `127.0.0.1`; openGym's CSRF
  check compares the `Origin` header, so the helpers send `Origin: $APP_ORIGIN`.
