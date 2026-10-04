#!/usr/bin/env bash
# shellcheck disable=SC2015
# Live test of a deployed template: the flows the local smoke covers, over HTTPS, plus the
# exercise media the instance downloaded on first start.
#
#   OWNER_PASSWORD_FILE=./owner-password tests/railway-smoke.sh https://<domain>
#
# Optional: OWNER_NAME (default Owner), SKIP_MEDIA=1 (instance deployed with EXERCISE_MEDIA=off),
# EXPECT_CLIENT_IP=<your public IP> (instance has AUDIT_IP=full): the activity log must record it.
# The owner password is read from a file (never an argument, never printed). Each run adds one
# invited test profile named rw-test-<timestamp>.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ $# -ge 1 ] || { sed -n '3,12p' "$0"; exit 2; }
APP_URL=${1%/}; APP_ORIGIN=$APP_URL; export APP_URL APP_ORIGIN
: "${OWNER_PASSWORD_FILE:?set OWNER_PASSWORD_FILE}"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "availability over HTTPS"
wait_for_code "$APP_URL/api/health" 200 300 && pass "the API answers over HTTPS" || die "not healthy"
hdr=$(curl -s -D- -o /dev/null --max-time 30 -X POST -H "Origin: $APP_ORIGIN" -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg n "$OWNER_NAME" '{name:$n,password:"wrong-on-purpose-0"}')" "$APP_URL/api/login/password" | tr -d '\r')
assert_contains "no session cookie for a wrong password" '^HTTP/[0-9.]* 401' "$hdr"

. "$REPO_ROOT/tests/flows.sh"

section "session cookie over HTTPS"
hdr=$(curl -s -D- -o /dev/null --max-time 30 -X POST -H "Origin: $APP_ORIGIN" -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg n "$OWNER_NAME" --arg p "$OWNER_PASSWORD" '{name:$n,password:$p}')" "$APP_URL/api/login/password" | tr -d '\r')
assert_contains "the session cookie is Secure (ORIGIN is https)" '^[Ss]et-[Cc]ookie:.*Secure' "$hdr"
assert_contains "the session cookie is HttpOnly" '^[Ss]et-[Cc]ookie:.*HttpOnly' "$hdr"

if [ -z "${SKIP_MEDIA:-}" ]; then
  section "exercise media (downloaded on first start)"
  wait_for_code "$APP_URL/img/0001-2gPfomN.jpg" 200 600 && pass "an exercise image is served" || fail "exercise image missing"
  assert_eq "an exercise animation is served" "200" "$(http_code "$APP_URL/gif/0001-2gPfomN.gif")"
fi

if [ -n "${EXPECT_CLIENT_IP:-}" ]; then
  section "the visitor's address reaches openGym (not the edge's)"
  api POST /api/login/password "$(jq -nc --arg n "$OWNER_NAME" '{name:$n,password:"wrong-on-purpose-1"}')" >/dev/null
  ip=$(body_of "$(api GET /api/admin/audit "" "$TEST_TMP/owner")" | jq -r '[.events[] | select(.ip != null)][0].ip')
  assert_eq "the activity log records the visitor's address" "$EXPECT_CLIENT_IP" "$ip"
  r=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -X POST -H "Origin: $APP_ORIGIN" -H 'X-Real-IP: 203.0.113.9' -H 'X-Forwarded-For: 203.0.113.9' \
    -H 'Content-Type: application/json' --data "$(jq -nc --arg n "$OWNER_NAME" '{name:$n,password:"wrong-on-purpose-2"}')" "$APP_URL/api/login/password")
  ip=$(body_of "$(api GET /api/admin/audit "" "$TEST_TMP/owner")" | jq -r '[.events[] | select(.ip != null)][0].ip')
  assert_eq "a forged X-Real-IP/X-Forwarded-For is not believed ($r)" "$EXPECT_CLIENT_IP" "$ip"
fi

summary
