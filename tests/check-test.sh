#!/usr/bin/env bash
# Tests for check.sh, the laptop half of the check.
# Usage: bash tests/check-test.sh
# The stubs in tests/stubs-host stand in for docker, curl and id. The sandbox
# is a real git clone made for each test.

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
. "$here/lib.sh"
CHECK="$here/../check.sh"
STUBS="$here/stubs-host"

# check ARGS...: runs check.sh against a sandbox clone with one commit.
check() {
  sandbox="$STATE/petclinic"
  if [ ! -d "$sandbox" ] && [ "${NO_SANDBOX:-0}" != 1 ]; then
    mkdir -p "$sandbox"
    git -C "$sandbox" init -q
    git -C "$sandbox" remote add origin "${ORIGIN:-https://github.com/qcon-ai-native-development/petclinic.git}"
    echo one > "$sandbox/file"
    git -C "$sandbox" add -A
    git -C "$sandbox" -c user.name=t -c user.email=t@example.invalid commit -q -m one
    [ "${DIRTY:-0}" = 1 ] && echo two > "$sandbox/file"
  fi
  commit="${WANT_COMMIT:-$(git -C "$sandbox" rev-parse HEAD 2>/dev/null)}"
  run env PATH="${STUB_PATH:-$STUBS}:$PATH" HE_SANDBOX_DIR="$sandbox" \
    HE_SANDBOX_COMMIT="$commit" bash "$CHECK" "$@"
}

called() { grep -q -- "$1" "$STATE/docker-calls" 2>/dev/null; }

all_pass() {
  check
  exits 0
  has_line '^PASS +platform '
  has_line '^PASS +docker +28\.0\.1, compose 2\.30\.0'
  has_line '^PASS +docker-memory +8 GB'
  has_line '^PASS +image +test-tag'
  has_line '^PASS +sandbox +commit [0-9a-f]{7}, no local changes'
  has_line '^PASS +container '
  has_line '^PASS +claude-model '
  has_line '^PASS +port +.*localhost:8080'
  no_line '^(WARN|FAIL) '
}
t "everything in place: all checks pass and the exit status is 0" all_pass

summary_block() {
  check
  has_line '^workshop check, .*docker 28\.0\.1$'
  has_line '^path: local docker$'
  has_line '^image: test-tag$'
  has_line '^1[0-9] pass, 0 warn, 0 fail$'
}
t "the summary names the path, the image and the counts of both halves" summary_block

no_docker() {
  mkdir -p "$STATE/nodocker"
  cp "$STUBS/curl" "$STUBS/id" "$STATE/nodocker/"
  # A PATH with the stubs but no docker at all, real or stubbed.
  mkdir -p "$STATE/bin"
  for tool in bash sh git sed awk grep df uname date head cut cat tr dirname sleep mktemp rm env sw_vers sysctl; do
    p="$(command -v "$tool" 2>/dev/null)" && ln -s "$p" "$STATE/bin/$tool"
  done
  sandbox="$STATE/petclinic"; mkdir -p "$sandbox"
  run env PATH="$STATE/nodocker:$STATE/bin" HE_SANDBOX_DIR="$sandbox" bash "$CHECK"
  exits 1
  has_line '^FAIL +docker +.*not found'
  no_line '^[A-Z]+ +image '
}
t "no docker client fails, and the checks that need Docker are skipped" no_docker

daemon_down() { STUB_DAEMON=down check; exits 1; has_line '^FAIL +docker +.*not running'; no_line '^[A-Z]+ +(image|container) '; }
t "a Docker that does not answer fails, and the checks that need it are skipped" daemon_down

no_compose() { STUB_COMPOSE=missing check; exits 1; has_line '^FAIL +docker +.*Compose'; }
t "Docker without Compose v2 fails" no_compose

low_memory() { STUB_MEM=2147483648 check; exits 0; has_line '^WARN +docker-memory +2 GB'; }
t "less than 4 GB for Docker warns" low_memory

image_missing() { STUB_IMAGE=missing check; exits 1; has_line '^FAIL +image +.*docker compose pull'; }
t "an image that is not pulled fails and names the command" image_missing

sandbox_missing() { NO_SANDBOX=1 check; exits 1; has_line '^FAIL +sandbox +.*git clone'; }
t "a missing sandbox clone fails and says to clone it" sandbox_missing

sandbox_other_commit() { WANT_COMMIT=0123456789abcdef0123456789abcdef01234567 check; exits 1; has_line '^FAIL +sandbox +.*expected 0123456'; }
t "a sandbox on another commit fails" sandbox_other_commit

sandbox_other_origin() {
  ORIGIN=https://github.com/spring-projects/spring-petclinic.git check
  has_line "^WARN +sandbox +origin is .*spring-petclinic.*expected .*qcon-ai-native-development/petclinic"
}
t "a clone of another PetClinic warns about its origin" sandbox_other_origin

sandbox_ssh_origin() {
  ORIGIN=git@github.com:qcon-ai-native-development/petclinic.git check
  no_line '^WARN +sandbox '
}
t "a clone over SSH is accepted" sandbox_ssh_origin

sandbox_dirty() { DIRTY=1 check; exits 0; has_line '^WARN +sandbox +.*local changes'; }
t "local changes in the sandbox warn" sandbox_dirty

container_down() {
  STUB_CONTAINER=down check
  exits 1
  has_line '^FAIL +container +.*docker compose up -d'
  called 'exec -T workshop he-check' && fail "ran the container half in a container that is not running"
  no_line '^[A-Z]+ +port '
}
t "a container that is not running fails, and the container half is skipped" container_down

inside_failure() {
  STUB_INSIDE='FAIL  claude-model     no answer from the model (Invalid API key). If you have not signed in yet: On the laptop, run: docker compose exec workshop claude' \
    STUB_INSIDE_EXIT=1 check --no-app
  exits 1
  has_line '^FAIL +claude-model '
  has_line '^FAIL claude-model: no answer'
  has_line ' 1 fail$'
}
t "a failure in the container half fails the whole check and reaches the summary" inside_failure

inside_cannot_run() {
  # shellcheck disable=SC2016 # Docker's own message, with a literal $PATH
  STUB_INSIDE='OCI runtime exec failed: exec: "he-check": executable file not found in $PATH' STUB_INSIDE_EXIT=127 check
  exits 1
  has_line '^FAIL +container-check '
}
t "a container without he-check fails with one clear line" inside_cannot_run

options_pass_through() {
  check --no-model --no-app
  called 'he-check --from-host --no-model --no-app' || fail "options did not reach he-check: $(cat "$STATE/docker-calls")"
  no_line '^[A-Z]+ +port '
}
t "--no-model and --no-app reach the container half, and --no-app skips the port" options_pass_through

port_blocked() { STUB_PORT=blocked check; exits 1; has_line '^FAIL +port +.*localhost:8080'; }
t "a published port that does not answer on the laptop fails" port_blocked

app_stopped_after() { check; called 'he-check --stop-app' || fail "PetClinic was left running"; }
t "PetClinic is stopped after the port test" app_stopped_after

app_stopped_after_port_failure() { STUB_PORT=blocked check; called 'he-check --stop-app' || fail "PetClinic was left running"; }
t "PetClinic is stopped after a failed port test too" app_stopped_after_port_failure

other_uid() {
  [ "$(uname -s)" = Linux ] || return 0
  STUB_UID=1001 check
  exits 0
  has_line '^WARN +user +.*1001'
}
t "on Linux, a user id other than 1000 warns" other_uid

home_hidden() {
  NO_SANDBOX=1 check
  no_line "$HOME"
}
t "the output shows the home folder as ~" home_hidden

unknown_option() { check --bogus; exits 2; }
t "an unknown option exits with status 2" unknown_option

finish
