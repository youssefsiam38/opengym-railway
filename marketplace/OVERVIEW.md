# Deploy and Host openGym on Railway

openGym is a self-hosted gym and body-weight tracker: plan a routine per weekday from 1,300+ exercises, run guided
workouts with a rest timer and pre-filled weights, log supersets, warm-ups and cardio, see which muscles are trained,
recovering or detrained, and track body weight and PRs. It installs as an app on your phone, works offline and syncs
across devices behind passkey sign-in. This is a community-maintained template, not affiliated with the openGym
project.

## About Hosting openGym

openGym is a Node API that stores everything as JSON files, plus a React frontend served by nginx that proxies `/api`
so both share one origin — which passkeys require. Passkeys also need HTTPS and a hostname they are bound to. A fresh
openGym has open sign-up and no admin, so on a public URL the first visitor could claim it.

This template runs both parts in one service on Railway's HTTPS domain, keeps all data on a volume, seeds an admin
profile on first boot and runs invite-only with the guest door closed. Exercise images and animations are downloaded
on first start, as openGym's own setup does.

## Common Use Cases

- A private workout log for yourself, synced between your phone and laptop.
- A small invite-only instance for a training partner, family or gym group, each with their own profile.
- Moving your history out of FitNotes, Strong or Hevy onto a server you control.

## Dependencies for openGym Hosting

- Nothing external — one service with a volume. Exercise media is fetched from GitHub on first start.

### Deployment Dependencies

- openGym: https://github.com/DuarteSantos8/openGym (AGPL-3.0)
- Template repository and tests: https://github.com/youssefsiam38/opengym-railway

### Implementation Details

The image combines openGym's official API and web images (pinned by digest, unmodified): nginx renders upstream's own
server block, serves the frontend on `PORT` 8080 and proxies `/api` to the API on loopback. `/storage` holds the data
directory and the exercise media. `RP_ID` and `ORIGIN` follow the Railway domain, so passkeys and `Secure` session
cookies work immediately.

On first boot an admin profile named `OWNER_NAME` is created with the generated `OWNER_PASSWORD`, hashed with
openGym's own password code. `INVITE_ONLY=1`, `ALLOW_GUEST=0` and `PASSWORD_LOGIN=1` are set. nginx takes the
visitor's address from Railway's edge so openGym's sign-in throttle counts real visitors.

Tested in CI and on a live deployment: sign-up without an invite is refused, the owner signs in and is an admin, an
invite admits one profile exactly once, workouts sync and stale writes are refused, photo uploads stay private, and
data, sessions and the owner survive a redeploy.

After deploying, copy `OWNER_PASSWORD` from the service's variables, open the URL, sign in with name `Owner` and that
password, then add a passkey in Settings and create invites from the admin dashboard. With a custom domain, set
`RP_ID` and `ORIGIN` to it and redeploy.

The exercise images and animations are third-party content, not covered by openGym's licence (see openGym's
NOTICE.md); set `EXERCISE_MEDIA=off` to skip them.

## Why Deploy openGym on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you
don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying openGym on Railway, you are one step closer to supporting a complete full-stack application with minimal
burden. Host your servers, databases, AI agents, and more on Railway.
