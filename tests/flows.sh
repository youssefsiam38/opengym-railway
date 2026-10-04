#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2154
# Product flows shared by smoke.sh (local) and railway-smoke.sh (live). Sourced after lib.sh, with
# APP_URL/APP_ORIGIN pointing at a running instance. Leaves the owner session in $TEST_TMP/owner.
# Profiles it creates are named rw-test-<timestamp> so re-runs never collide.

section "one origin: frontend and API"
root=$(curl -s --max-time 30 -D "$TEST_TMP/root.h" "$APP_URL/")
assert_contains "the frontend is served at /" '<div id="root"' "$root"
assert_contains "frames are refused (upstream's nginx headers)" 'x-frame-options: deny' "$(tr -d '\r' < "$TEST_TMP/root.h" | tr '[:upper:]' '[:lower:]')"
cfg=$(curl -s --max-time 30 "$APP_URL/api/config")
assert_eq "sign-up is invite-only" "true" "$(jq -r .invite_only <<<"$cfg")"
assert_eq "the guest door is closed" "false" "$(jq -r .allow_guest <<<"$cfg")"
assert_eq "password sign-in is on (the owner's way in)" "true" "$(jq -r .password_login <<<"$cfg")"
assert_eq "a deep path is sent back to the app root" "302" "$(http_code "$APP_URL/some/deep/path")"

section "open sign-up is closed"
r=$(api POST /api/register/password '{"name":"rw-intruder","password":"intruder-pass-0000"}')
assert_eq "password sign-up without an invite is refused" "403" "$(code_of "$r")"
r=$(api POST /api/register/options '{"name":"rw-intruder"}')
assert_eq "passkey sign-up without an invite is refused" "403" "$(code_of "$r")"
r=$(api POST /api/register/options '{"name":"rw-intruder","code":"0123456789ABCDEF"}')
assert_eq "a made-up invite code is refused" "403" "$(code_of "$r")"
assert_eq "the data API needs a session" "401" "$(code_of "$(api GET /api/data)")"
assert_eq "the admin API needs a session" "401" "$(code_of "$(api GET /api/admin/users)")"

section "the seeded owner"
owner="$TEST_TMP/owner"; : > "$owner"
assert_eq "a wrong owner password is refused" "401" "$(code_of "$(api POST /api/login/password "$(jq -nc --arg n "$OWNER_NAME" '{name:$n,password:"definitely-wrong-pw"}')")")"
login "$owner" "$OWNER_NAME" "$OWNER_PASSWORD" && pass "the owner signs in with name + password" || die "owner sign-in failed"
me=$(body_of "$(api GET /api/me "" "$owner")")
assert_eq "the session is the owner's" "$OWNER_NAME" "$(jq -r '.user.name // .name' <<<"$me")"
assert_eq "the owner is an admin" "true" "$(jq -r 'if .user then .user.admin else .admin end' <<<"$me")"
users=$(api GET /api/admin/users "" "$owner")
assert_eq "the admin dashboard API answers the owner" "200" "$(code_of "$users")"

section "invites admit a profile exactly once"
inv=$(api POST /api/admin/invites/new '{"note":"railway test"}' "$owner")
assert_eq "the owner creates an invite" "200" "$(code_of "$inv")"
code=$(body_of "$inv" | jq -r .invite.code)
member="rw-test-$(date +%s)"; mpw="member-pass-$(date +%s)-x"
mjar="$TEST_TMP/member"; : > "$mjar"
r=$(api POST /api/register/password "$(jq -nc --arg n "$member" --arg p "$mpw" --arg c "$code" '{name:$n,password:$p,code:$c}')" "$mjar")
assert_eq "a new profile signs up with the invite" "200" "$(code_of "$r")"
r=$(api POST /api/register/password "$(jq -nc --arg n "$member-2" --arg p "$mpw" --arg c "$code" '{name:$n,password:$p,code:$c}')")
assert_eq "the same invite is refused a second time" "403" "$(code_of "$r")"
me=$(body_of "$(api GET /api/me "" "$mjar")")
assert_eq "the member is signed in" "$member" "$(jq -r '.user.name // .name' <<<"$me")"
assert_eq "the member is not an admin" "false" "$(jq -r 'if .user then .user.admin else .admin end' <<<"$me")"
assert_eq "the member cannot open the admin API" "403" "$(code_of "$(api GET /api/admin/users "" "$mjar")")"
login "$TEST_TMP/member2" "$member" "$mpw" && pass "the member signs in again with their password" || fail "member password sign-in"

section "workouts sync through the API"
rev=$(body_of "$(api GET /api/data "" "$owner")" | jq -r '.rev')
wid="rw-$(date +%s)"
state=$(jq -nc --arg id "$wid" '{workouts:[{id:$id,d:"2026-10-04",name:"Railway test day",ex:[]}],routines:[],bw:[]}')
r=$(api PUT /api/data "$(jq -nc --argjson s "$state" --argjson b "$rev" '{state:$s,baseRev:$b}')" "$owner")
assert_eq "a workout is saved" "200" "$(code_of "$r")"
got=$(body_of "$(api GET /api/data "" "$owner")")
assert_eq "the workout reads back" "$wid" "$(jq -r '.state.workouts[0].id' <<<"$got")"
r=$(api PUT /api/data "$(jq -nc --argjson s "$state" --argjson b "$rev" '{state:$s,baseRev:$b}')" "$owner")
assert_eq "a stale write is refused, not silently merged (409)" "409" "$(code_of "$r")"
assert_eq "another profile cannot see it" "null" "$(body_of "$(api GET /api/data "" "$mjar")" | jq -r '.state.workouts[0].id // null')"
r=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -b "$owner" -X PUT -H 'Origin: https://evil.example' -H 'Content-Type: application/json' --data '{"state":{"workouts":[]}}' "$APP_URL/api/data")
assert_eq "a cross-origin write is refused (CSRF)" "403" "$r"

section "custom-exercise photo upload (nginx media route + volume)"
png="$REPO_ROOT/tests/fixtures/exercise.png"
h=$(sha256sum "$png" | cut -d' ' -f1)
r=$(curl -s -w '\n%{http_code}' --max-time 60 -b "$owner" -X PUT -H "Origin: $APP_ORIGIN" -H 'Content-Type: image/png' --data-binary @"$png" "$APP_URL/api/media/$h")
assert_contains "the photo is accepted" '^20[01]$' "$(tail -n1 <<<"$r")"
assert_eq "the photo reads back byte for byte" "$h" "$(curl -s --max-time 30 -b "$owner" "$APP_URL/api/media/$h" | sha256sum | cut -d' ' -f1)"
assert_eq "another profile cannot read it" "404" "$(http_code -b "$mjar" "$APP_URL/api/media/$h")"
assert_eq "it is private without a session" "401" "$(http_code "$APP_URL/api/media/$h")"
