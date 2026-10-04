# openGym on Railway

A one-click [Railway](https://railway.com) template for [openGym](https://github.com/DuarteSantos8/openGym), the
self-hosted gym and body-weight tracker: plan routines, log workouts, see which muscles are trained or recovering,
import from FitNotes/Strong/Hevy, passkey sign-in, synced across devices.

Community-maintained; not affiliated with the openGym project.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opengym)

## What you get

- **One service, one volume.** openGym's official API image with its official web build in the same container:
  nginx serves the app on Railway's public HTTPS domain and proxies `/api` to the API, so the app and API share one
  origin (passkeys require it). Everything persistent is on the `/storage` volume.
- **Closed by default.** A fresh openGym has open sign-up and no admin. This template seeds an admin profile on first
  boot and runs **invite-only** with **no guest door**, so nobody else can create a profile on your public URL.
- **Passkeys work out of the box.** `RP_ID`/`ORIGIN` follow the Railway domain.
- **Exercise media** (1,324 images + animations, ~140 MB) is downloaded on first start, as upstream's compose does.

## After deploying

1. Open the service's **Variables** and copy `OWNER_PASSWORD`.
2. Open the public URL, choose password sign-in, and sign in as `OWNER_NAME` (default `Owner`).
3. In **Settings**, add a passkey (and change the password if you like).
4. **Settings → Admin dashboard → Invites** creates invite codes for anyone else.

`OWNER_PASSWORD` is only read on the very first start; changing it later does nothing. A forgotten password is reset
by another admin from the dashboard, or by signing in with a passkey.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `OWNER_NAME` | `Owner` | Profile name of the first-boot admin |
| `OWNER_PASSWORD` | generated | Its password (first boot only) |
| `INVITE_ONLY` | `1` | New profiles need an invite code |
| `ALLOW_GUEST` | `0` | `1` offers browser-only guest mode |
| `PASSWORD_LOGIN` | `1` | Name + password sign-in next to passkeys |
| `RP_ID` / `ORIGIN` | Railway domain | Passkey hostname / app URL. Change both for a custom domain |
| `EXERCISE_MEDIA` | `download` | `off` skips the exercise image/animation download |
| `DEFAULT_LANG`, `SESSION_DAYS`, `VAPID_SUBJECT`, `COACH_DISABLED`, `AUDIT_IP` | unset | Optional; see openGym's `.env.example` |

**Custom domain:** set `RP_ID=gym.example.com` and `ORIGIN=https://gym.example.com`, then redeploy. Passkeys are
bound to the hostname they were created on, so passkeys made on the old domain stop working; sign in with your
password and add a new one.

## Repository

| Path | |
|---|---|
| `images/app/` | Wrapper image: Dockerfile, entrypoint, nginx main config, owner seed |
| `tests/` | `static.sh`, `smoke.sh`, `persistence.sh` (local), `railway-smoke.sh` (live) |
| `marketplace/OVERVIEW.md` | Marketplace page |
| `RAILWAY_TEMPLATE.md` | Exact template configuration |

See [ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](SECURITY.md), [MAINTENANCE.md](MAINTENANCE.md).

## Licence

Wrapper code in this repository: MIT ([LICENSE](LICENSE)). openGym itself: AGPL-3.0
([licenses/OPENGYM-LICENSE](licenses/OPENGYM-LICENSE)); the image runs it unmodified. Exercise images and
animations are third-party content — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
