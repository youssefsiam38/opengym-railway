# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | openGym |
| Code | `opengym` |
| Template id | `2ecc98ac-b343-421f-a46b-978170c0b3e3` |
| Deploy URL | https://railway.com/deploy/opengym |
| Category | Other |
| Card description | Self-hosted gym tracker with passkeys: routines, workouts, muscle map. |
| Icon | `assets/icon.png` via https://raw.githubusercontent.com/youssefsiam38/opengym-railway/v1.0.1/assets/icon.png |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |
| Skeleton project | `openGym` (`6454a57b-612e-41af-8972-3229cc7f6ceb`), never deployed |

Generated values use Railway's `secret()` function: `alnum24` is `${{secret(24, "a-zA-Z0-9")}}` spelled out. Images
are referenced by tag because the template generator rejects digests.

## Service `opengym`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/opengym-railway:1.0.1` (`sha256:9f47f236bd31fea022cf92937637c8fa58525b4447685e1de8df48e5dcb66f0b`) |
| Public domain | target port 8080 |
| Volume | `/storage` |
| Healthcheck | `/api/health` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `PORT` | `8080` |
| `RP_ID` | `${{RAILWAY_PUBLIC_DOMAIN}}` |
| `ORIGIN` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |
| `RP_NAME` | `openGym` |
| `OWNER_NAME` | `Owner` |
| `OWNER_PASSWORD` | generated, alnum24 |
| `INVITE_ONLY` | `1` |
| `ALLOW_GUEST` | `0` |
| `PASSWORD_LOGIN` | `1` |
| `TRUST_PROXY` | `1` |
| `EXERCISE_MEDIA` | `download` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `120` |
| `DEFAULT_LANG`, `SESSION_DAYS`, `VAPID_SUBJECT`, `COACH_DISABLED`, `AUDIT_IP` | optional, unset |

## Notes

- No required deploy input: `railway deploy -t opengym` works headless.
- Rebuild: `_audit/spec_opengym.py` with `_audit/tplkit.py` (`skeleton` → `railway templates create` → `patch_template`
  → `templates publish --readme-file marketplace/OVERVIEW.md`).
- Live gates on 2026-10-04: draft template 40/40 (`tests/railway-smoke.sh` with `EXPECT_CLIENT_IP`), redeploy 8/8
  (`tests/railway-redeploy-verify.sh`), published code `opengym` 40/40.
