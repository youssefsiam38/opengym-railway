#!/usr/bin/env bash
# shellcheck disable=SC2015
# Run after redeploying a live instance that railway-smoke.sh already exercised: the owner, their
# session secret, workouts, uploads and the exercise media must all still be there, and the owner
# must not have been re-seeded.
#
#   OWNER_PASSWORD_FILE=./owner-password tests/railway-redeploy-verify.sh https://<domain> <users-before>
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
[ $# -ge 2 ] || { sed -n '3,8p' "$0"; exit 2; }
APP_URL=${1%/}; APP_ORIGIN=$APP_URL; USERS_BEFORE=$2; export APP_URL APP_ORIGIN
: "${OWNER_PASSWORD_FILE:?set OWNER_PASSWORD_FILE}"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "after a redeploy"
wait_for_code "$APP_URL/api/health" 200 300 && pass "the API answers" || die "not healthy"
assert_eq "no profile was added or lost" "$USERS_BEFORE" "$(curl -s "$APP_URL/api/health" | jq -r .users)"
jar="$TEST_TMP/owner"; : > "$jar"
login "$jar" "$OWNER_NAME" "$OWNER_PASSWORD" && pass "the owner still signs in" || die "owner sign-in failed"
assert_eq "the owner's workouts survived" "true" "$(body_of "$(api GET /api/data "" "$jar")" | jq -r '(.state.workouts | length) > 0')"
assert_eq "the owner is still an admin" "true" "$(body_of "$(api GET /api/me "" "$jar")" | jq -r '.user.admin')"
png="$REPO_ROOT/tests/fixtures/exercise.png"; h=$(sha256sum "$png" | cut -d' ' -f1)
assert_eq "the uploaded photo survived" "$h" "$(curl -s --max-time 30 -b "$jar" "$APP_URL/api/media/$h" | sha256sum | cut -d' ' -f1)"
assert_eq "the exercise media survived (no re-download needed)" "200" "$(http_code "$APP_URL/img/0001-2gPfomN.jpg")"
if [ -n "${SESSION_JAR:-}" ]; then
  assert_eq "a session from before the redeploy is still valid" "200" "$(code_of "$(api GET /api/me "" "$SESSION_JAR")")"
fi

summary
