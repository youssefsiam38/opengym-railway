#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: everything openGym keeps (profiles, passkeys, sessions' signing secret, workouts,
# uploads) lives on the /storage volume. Recreate the container — once with a different
# OWNER_PASSWORD — and check nothing was lost and the owner was not re-seeded. Standalone.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'compose logs --no-color --tail 80 || true; compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"' EXIT

section "first boot"
compose up -d --build >/dev/null 2>&1 || die "compose up failed"
wait_for_code "$APP_URL/api/health" 200 240 || die "app never became healthy"
jar="$TEST_TMP/owner"; : > "$jar"
login "$jar" "$OWNER_NAME" "$OWNER_PASSWORD" || die "owner sign-in failed"
wid="persist-$(date +%s)"
api PUT /api/data "$(jq -nc --arg id "$wid" '{state:{workouts:[{id:$id,d:"2026-10-04",name:"Persist"}],routines:[]}}')" "$jar" >/dev/null
png="$REPO_ROOT/tests/fixtures/exercise.png"; h=$(sha256sum "$png" | cut -d' ' -f1)
curl -s -o /dev/null --max-time 60 -b "$jar" -X PUT -H "Origin: $APP_ORIGIN" -H 'Content-Type: image/png' --data-binary @"$png" "$APP_URL/api/media/$h"
users_before=$(curl -s "$APP_URL/api/health" | jq -r .users)

section "recreate the container with a different OWNER_PASSWORD"
OPENGYM_TEST_OWNER_PASSWORD="a-changed-owner-password-1" compose up -d --force-recreate >/dev/null 2>&1 || die "recreate failed"
wait_for_code "$APP_URL/api/health" 200 240 || die "app never came back"
assert_eq "no profile was added or lost" "$users_before" "$(curl -s "$APP_URL/api/health" | jq -r .users)"
assert_eq "the session from before the restart is still valid (secret kept)" "200" "$(code_of "$(api GET /api/me "" "$jar")")"
assert_eq "the workout survived" "$wid" "$(body_of "$(api GET /api/data "" "$jar")" | jq -r '.state.workouts[0].id')"
assert_eq "the uploaded photo survived" "$h" "$(curl -s --max-time 30 -b "$jar" "$APP_URL/api/media/$h" | sha256sum | cut -d' ' -f1)"
login "$TEST_TMP/again" "$OWNER_NAME" "$OWNER_PASSWORD" && pass "the original owner password still signs in" || fail "original owner password refused"
if login "$TEST_TMP/changed" "$OWNER_NAME" "a-changed-owner-password-1"; then fail "a changed OWNER_PASSWORD re-seeded the owner"; else pass "a changed OWNER_PASSWORD does not overwrite the owner"; fi

summary
