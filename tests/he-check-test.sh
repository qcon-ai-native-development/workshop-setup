#!/usr/bin/env bash
# Tests for image/he-check, the container half of the check.
# Usage: bash tests/he-check-test.sh
# The stubs in tests/stubs-inside stand in for java, claude, opencode, curl and
# the sandbox's Maven wrapper.

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
. "$here/lib.sh"
HE_CHECK="$here/../image/he-check"
STUBS="$here/stubs-inside"

# he_check ARGS...: runs he-check on a fake sandbox, a git clone with one commit.
he_check() {
  work="$STATE/work"
  if [ ! -d "$work" ]; then
    mkdir -p "$work"
    [ "${NO_MVNW:-0}" = 1 ] || cp "$STUBS/mvnw" "$work/mvnw"
    git -C "$work" init -q
    git -C "$work" add -A
    git -C "$work" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
  fi
  run env PATH="$STUBS:$PATH" HE_WORK="$work" HE_CLAUDE_VERSION=2.1.281 \
    HE_IMAGE_TAG=test-tag HE_CHECK_APP_TIMEOUT="${APP_TIMEOUT:-5}" \
    bash "$HE_CHECK" "$@"
}

app_stopped() {
  if [ -e "$STATE/app-pid" ] && kill -0 "$(cat "$STATE/app-pid")" 2>/dev/null; then
    fail "PetClinic is still running"
    kill "$(cat "$STATE/app-pid")" 2>/dev/null
  fi
}

all_pass() {
  he_check
  exits 0
  has_line '^PASS +java +17\.0\.13'
  has_line '^PASS +build '
  has_line '^PASS +claude +2\.1\.281'
  has_line '^PASS +claude-model '
  has_line '^PASS +app '
  has_line '^PASS +network '
  has_line '^PASS +opencode +1\.18\.32'
  no_line '^(WARN|FAIL) '
  has_line '^8 pass, 0 warn, 0 fail$'
}
t "everything in place: all checks pass and the exit status is 0" all_pass

java_21() { STUB_JAVA_VERSION=21.0.5 he_check --no-app; exits 1; has_line '^FAIL +java +21\.0\.5'; }
t "a JDK other than 17 fails" java_21

compile_fails() { STUB_COMPILE_EXIT=1 he_check --no-app; exits 1; has_line '^FAIL +build '; }
t "a failed offline compile fails the build check" compile_fails

compile_offline() { he_check --no-app; grep -q -- '-o .*compile' "$STATE/mvnw-calls" || fail "compile did not run offline: $(cat "$STATE/mvnw-calls")"; }
t "the compile runs in Maven's offline mode" compile_offline

no_sandbox() { NO_MVNW=1 he_check; exits 1; has_line '^FAIL +build .*no Maven wrapper'; no_line '^[A-Z]+ +app '; }
t "a work folder without the Maven wrapper fails build and skips the app" no_sandbox

claude_other_version() { STUB_CLAUDE_VERSION=2.2.0 he_check --no-app; exits 0; has_line '^WARN +claude +2\.2\.0.*2\.1\.281'; }
t "another Claude Code version warns" claude_other_version

not_signed_in() {
  STUB_CLAUDE_REPLY='Invalid API key · Please run /login' STUB_CLAUDE_EXIT=1 he_check --no-app
  exits 1
  has_line '^FAIL +claude-model .*docker compose exec workshop claude'
}
t "a model call that does not answer fails and says how to sign in" not_signed_in

signed_in_codespace() {
  STUB_CLAUDE_REPLY='' STUB_CLAUDE_EXIT=1 CODESPACES=true he_check --no-app
  has_line '^FAIL +claude-model .*Run: claude'
  no_line 'docker compose'
}
t "in a Codespace the sign-in hint names no docker command" signed_in_codespace

model_outside_work() {
  he_check --no-app
  case "$(cat "$STATE/claude-cwd")" in
    "$STATE/work"*) fail "the model call ran inside the sandbox: $(cat "$STATE/claude-cwd")" ;;
  esac
}
t "the model call runs outside the sandbox" model_outside_work

no_model() {
  he_check --no-model --no-app
  exits 0
  no_line '^[A-Z]+ +claude-model '
  [ ! -e "$STATE/claude-cwd" ] || fail "claude was called for a model reply"
}
t "--no-model makes no model call" no_model

app_starts_and_stops() { he_check --no-model; has_line '^PASS +app '; app_stopped; }
t "the app check starts PetClinic and stops it afterwards" app_starts_and_stops

app_never_answers() { STUB_APP=never APP_TIMEOUT=2 he_check --no-model; exits 1; has_line '^FAIL +app .*2 seconds'; app_stopped; }
t "an application that never answers fails, and is stopped" app_never_answers

app_already_running() {
  mkdir -p "$STATE"; touch "$STATE/app-up"
  he_check --no-model
  has_line '^PASS +app .*already running'
  if grep -q 'spring-boot:run' "$STATE/mvnw-calls" 2>/dev/null; then fail "started a second PetClinic"; fi
  [ -e "$STATE/app-up" ] || fail "stopped an application it did not start"
}
t "an application that already answers is tested and left alone" app_already_running

from_host_keeps_app() {
  he_check --from-host --no-model
  has_line '^PASS +app '
  kill -0 "$(cat "$STATE/app-pid")" 2>/dev/null || fail "PetClinic was stopped before the laptop could test the port"
  he_check --stop-app
  exits 0
  app_stopped
}
t "--from-host leaves PetClinic running until --stop-app" from_host_keeps_app

no_app() { he_check --no-model --no-app; no_line '^[A-Z]+ +app '; [ ! -e "$STATE/app-pid" ] || fail "PetClinic was started"; }
t "--no-app skips the application" no_app

network_down() { STUB_NET=down he_check --no-app; exits 1; has_line '^FAIL +network .*api\.anthropic\.com'; }
t "an unreachable api.anthropic.com fails" network_down

opencode_broken() { STUB_OPENCODE=fail he_check --no-app; exits 0; has_line '^WARN +opencode '; }
t "a broken OpenCode warns and does not fail the check" opencode_broken

from_host_lines_only() {
  he_check --from-host --no-app
  no_line 'Paste the block'
  no_line '^[A-Z]+ +sandbox '
  no_line 'pass, .* warn'
}
t "--from-host prints check lines only: no sandbox line, no summary" from_host_lines_only

summary_container() {
  he_check --no-app
  has_line '^PASS +sandbox +commit [0-9a-f]{7}'
  has_line '^workshop check, '
  has_line '^path: container$'
  has_line '^image: test-tag$'
}
t "run alone, it reports the sandbox commit and a summary block" summary_container

summary_codespace() { CODESPACES=true he_check --no-app; has_line '^path: codespaces$'; }
t "in a Codespace the summary says so" summary_codespace

summary_lists_problems() {
  STUB_JAVA_VERSION=21.0.5 STUB_OPENCODE=fail he_check --no-app
  has_line '^FAIL java: '
  has_line '^WARN opencode: '
}
t "the summary block repeats each warning and failure" summary_lists_problems

work_from_cwd() {
  mkdir -p "$STATE/clone" && cp "$STUBS/mvnw" "$STATE/clone/mvnw"
  git -C "$STATE/clone" init -q && git -C "$STATE/clone" add -A
  git -C "$STATE/clone" -c user.name=t -c user.email=t@example.invalid commit -q -m one
  mkdir -p "$STATE/clone/src"
  # shellcheck disable=SC2016 # $1 and $2 belong to the inner shell
  run env -u HE_WORK PATH="$STUBS:$PATH" bash -c 'cd "$1" && bash "$2" --no-model --no-app' _ "$STATE/clone/src" "$HE_CHECK"
  has_line '^PASS +build '
  grep -q compile "$STATE/mvnw-calls" 2>/dev/null || fail "the clone's Maven wrapper was not used"
}
t "without HE_WORK, started inside a clone, it checks that clone (the Codespaces case)" work_from_cwd

unknown_option() { he_check --bogus; exits 2; }
t "an unknown option exits with status 2" unknown_option

finish
