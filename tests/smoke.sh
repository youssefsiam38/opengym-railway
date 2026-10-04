#!/usr/bin/env bash
# shellcheck disable=SC2015
# Smoke test: build + bring the stack up and exercise the product flows — the app and its API share
# one origin, sign-up is invite-only with no guest door, the seeded owner signs in and is an admin,
# invites admit a new profile exactly once, workouts sync through /api/data, and a custom-exercise
# photo upload round-trips. Standalone.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
if [ -z "${KEEP_STACK:-}" ]; then
  trap 'compose logs --no-color --tail 120 || true; compose down -v --remove-orphans >/dev/null 2>&1 || true; rm -rf "$TEST_TMP"' EXIT
  section "bring the stack up"
  compose up -d --build >/dev/null 2>&1 || die "compose up failed"
fi
wait_for_code "$APP_URL/api/health" 200 240 && pass "the API answers through nginx" || die "app never became healthy"

. "$REPO_ROOT/tests/flows.sh"

summary
