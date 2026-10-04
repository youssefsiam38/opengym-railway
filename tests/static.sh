#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
# Static validation: syntax, shellcheck, compose, upstream image pins and configuration. No Docker build.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"

section "syntax"
for f in tests/*.sh images/app/entrypoint.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done
if command -v node >/dev/null; then
  if node --check images/app/seed-owner.mjs; then pass "parses: seed-owner.mjs"; else fail "syntax error: seed-owner.mjs"; fi
fi

section "shellcheck"
if command -v shellcheck >/dev/null; then
  if shellcheck -x -s bash tests/*.sh && shellcheck -s sh images/app/entrypoint.sh; then pass "shellcheck"; else fail "shellcheck"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cfg=$(docker compose -f compose.yaml config --format json)
assert_eq "one service" "app" "$(jq -r '[.services | keys[]] | sort | join(" ")' <<<"$cfg")"
assert_eq "the app binds to loopback" "127.0.0.1" "$(jq -r '[.services.app.ports[]? | .host_ip] | join(" ")' <<<"$cfg")"
assert_eq "nginx listens on 8080" "8080" "$(jq -r '[.services.app.ports[]? | .target] | join(" ")' <<<"$cfg")"
assert_eq "the /storage volume is mounted" "/storage" "$(jq -r '[.services.app.volumes[]? | .target] | join(" ")' <<<"$cfg")"

section "image pins"
for v in API WEB; do
  assert_contains "the $v image is the official openGym image, pinned by digest" \
    "^ARG OPENGYM_${v}_IMAGE=ghcr.io/duartesantos8/opengym-$(tr '[:upper:]' '[:lower:]' <<<"$v"):[0-9.]*@sha256:[0-9a-f]\{64\}$" \
    "$(grep "^ARG OPENGYM_${v}_IMAGE=" images/app/Dockerfile)"
done
api_v=$(grep '^ARG OPENGYM_API_IMAGE=' images/app/Dockerfile | sed 's/@.*//; s/.*://')
web_v=$(grep '^ARG OPENGYM_WEB_IMAGE=' images/app/Dockerfile | sed 's/@.*//; s/.*://')
assert_eq "API and web images are the same openGym release" "$api_v" "$web_v"

section "closed-instance posture"
env_json=$(jq -c '.services.app.environment' <<<"$cfg")
assert_eq "invite-only sign-up" "1" "$(jq -r .INVITE_ONLY <<<"$env_json")"
assert_eq "no guest door" "0" "$(jq -r .ALLOW_GUEST <<<"$env_json")"
assert_eq "password sign-in on (the seeded owner's way in)" "1" "$(jq -r .PASSWORD_LOGIN <<<"$env_json")"
assert_contains "the compose owner password is a placeholder" 'local-test-only' "$(jq -r .OWNER_PASSWORD <<<"$env_json")"
assert_contains "the seed never overwrites existing profiles" 'db.users.length > 0' "$(cat images/app/seed-owner.mjs)"
assert_contains "the seed uses openGym's own password hashing" "from './password.js'" "$(cat images/app/seed-owner.mjs)"
assert_contains "nginx takes the client address from the edge's last X-Forwarded-For entry" 'real_ip_recursive off' "$(cat images/app/nginx.conf)"
if grep -q 'OWNER_PASSWORD' images/app/entrypoint.sh && ! grep -qE 'log .*\$\{?OWNER_PASSWORD' images/app/entrypoint.sh; then
  pass "the entrypoint never logs the owner password"
else
  fail "the entrypoint may log the owner password"
fi

section "media is downloaded, never shipped"
assert_contains "the media comes from the upstream dataset at run time" 'hasaneyldrm/exercises-dataset' "$(cat images/app/entrypoint.sh)"
if grep -qE '\.(jpg|gif)' .dockerignore 2>/dev/null || ! find . -path ./.git -prune -o \( -name '*.jpg' -o -name '*.gif' \) -print | grep -q .; then
  pass "no exercise media in the repository"
else
  fail "exercise media found in the repository"
fi

section "secrets hygiene"
mapfile -t tracked < <(git ls-files 2>/dev/null | grep . || find . -type f -not -path './.git/*' -not -path './test-output/*')
if [ "${#tracked[@]}" -gt 0 ] && grep -lE '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' "${tracked[@]}" 2>/dev/null; then
  fail "a credential-shaped string is in the repository"
else
  pass "no credential-shaped strings in ${#tracked[@]} files"
fi

summary
