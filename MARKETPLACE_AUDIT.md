# Marketplace audit

## Identity

- Template: **openGym** — self-hosted gym and body-weight tracker with passkey sign-in.
- Upstream: [DuarteSantos8/openGym](https://github.com/DuarteSantos8/openGym), AGPL-3.0, ~2.5k stars, very active
  (v1.3.9, 2026-09-28). No competing Railway template at publication (searched "openGym", "gym tracker", "workout").

## Licence

- **openGym: AGPL-3.0** (`licenses/OPENGYM-LICENSE`, upstream NOTICE in `licenses/OPENGYM-NOTICE.md`). The official
  images run unmodified; the wrapper adds files beside them. No brand policy found; the template uses its own generic
  icon and a non-affiliation note anyway.
- **Exercise images/animations:** third-party, ownership disputed per upstream's NOTICE, licensed to neither openGym
  nor deployers. The template does not ship them: like upstream's compose, each instance downloads them from the
  public dataset on first start. Disclosed in the overview, README and THIRD_PARTY_NOTICES; `EXERCISE_MEDIA=off`
  opts out.

## Security review

- **Open sign-up closed.** Upstream defaults to open sign-up with no admin. The template seeds an admin owner
  (openGym's own scrypt hash, `admin: true`) and sets `INVITE_ONLY=1`, `ALLOW_GUEST=0`. Verified live: password and
  passkey sign-up without/with a fake invite → 403; an invite admits exactly one profile; members are not admins.
- **Real client addresses.** Railway's edge overwrites `X-Real-IP` (verified with an echo service); nginx uses it, so
  openGym's throttle and audit log see visitors, and forged headers are ignored (verified live).
- **Cookies/CSRF.** `ORIGIN` https → `Secure; HttpOnly` session cookie; cross-origin writes → 403 (verified live).
- **Secrets.** `OWNER_PASSWORD` generated, never logged; tests read it from a 0600 file.
- **Reproducible.** Upstream images pinned by digest; wrapper built and tested in CI on each tag.

## Tests

- `tests/static.sh` (29), `tests/smoke.sh` (33), `tests/persistence.sh` (6) — local and in CI.
- `tests/railway-smoke.sh` (40 with `EXPECT_CLIENT_IP`) and `tests/railway-redeploy-verify.sh` (8) — live.
- Browser: sign-in screen rendered on the live deploy (passkey, password, invite-gated create; no guest button).
  Passkey ceremonies and the UI flows past sign-in were covered at the API level only.

## Verdict

Shippable and published 2026-10-04 as `opengym`.
