#!/usr/bin/env bash
# shellcheck disable=SC2015
# Shared helpers for opengym-railway tests. Source this file; do not execute it.
#
# openGym's API is plain JSON over /api. The owner signs in with openGym's password sign-in
# (POST /api/login/password) and gets a session cookie. State-changing requests are sent with
# Origin = APP_ORIGIN (openGym's CSRF check compares it to its ORIGIN). Secrets are never echoed.

: "${APP_URL:=http://127.0.0.1:${OPENGYM_TEST_PORT:-18080}}"
: "${APP_ORIGIN:=http://localhost:${OPENGYM_TEST_PORT:-18080}}"
: "${TEST_TIMEOUT:=300}"
: "${OWNER_NAME:=${OPENGYM_TEST_OWNER_NAME:-Owner}}"
if [ -n "${OWNER_PASSWORD_FILE:-}" ]; then OWNER_PASSWORD=$(cat "$OWNER_PASSWORD_FILE"); fi
: "${OWNER_PASSWORD:=${OPENGYM_TEST_OWNER_PASSWORD:-local-test-only-owner-pw}}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -q -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@" || true; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url")
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }

# api METHOD PATH [JSON] [JAR] -> prints "<code> <body>" (body on one line).
api() {
  local m=$1 p=$2 d=${3:-} jar=${4:-} args
  args=(-s --max-time 60 -X "$m" -H "Origin: $APP_ORIGIN" -w '\n%{http_code}')
  [ -n "$jar" ] && args+=(-b "$jar" -c "$jar")
  [ -n "$d" ] && args+=(-H 'Content-Type: application/json' --data "$d")
  local out; out=$(curl "${args[@]}" "$APP_URL$p" || true)
  printf '%s %s' "$(tail -n1 <<<"$out")" "$(sed '$d' <<<"$out" | tr -d '\n')"
}
code_of() { cut -d' ' -f1 <<<"$1"; }
body_of() { cut -d' ' -f2- <<<"$1"; }

# login JAR NAME PASSWORD -> 0 when openGym's password sign-in answers 200 and sets a session.
login() {
  local r; r=$(api POST /api/login/password "$(jq -nc --arg n "$2" --arg p "$3" '{name:$n,password:$p}')" "$1")
  [ "$(code_of "$r")" = 200 ]
}
