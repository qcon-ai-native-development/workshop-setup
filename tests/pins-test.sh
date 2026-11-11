#!/usr/bin/env bash
# Tests that the pins agree: the sandbox commit in check.sh and in the
# Dockerfile, and the image tag in compose.yaml and in the sandbox's
# devcontainer.json.
# Usage: bash tests/pins-test.sh

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=tests/lib.sh
. "$here/lib.sh"
root="$here/.."

pin() { sed -n "$2" "$root/$1" | head -n 1; }

sandbox_commit() {
  OUT=""
  # shellcheck disable=SC2016 # a sed pattern that matches a literal ${...}
  in_check="$(pin check.sh 's/^SANDBOX_COMMIT="\${HE_SANDBOX_COMMIT:-\([0-9a-f]\{40\}\)}"$/\1/p')"
  in_image="$(pin Dockerfile 's/^ARG SANDBOX_COMMIT=\([0-9a-f]\{40\}\)$/\1/p')"
  [ -n "$in_check" ] || fail "no 40-character SANDBOX_COMMIT in check.sh"
  [ "$in_check" = "$in_image" ] || fail "check.sh pins '$in_check', the Dockerfile '$in_image'"
}
t "check.sh and the Dockerfile pin the same sandbox commit" sandbox_commit

sandbox_repository() {
  OUT=""
  in_check="$(pin check.sh 's/^SANDBOX_URL="\(.*\)"$/\1/p')"
  in_image="$(pin Dockerfile 's/^ARG SANDBOX_REPO=\(.*\)$/\1/p')"
  [ -n "$in_check" ] || fail "no SANDBOX_URL in check.sh"
  [ "$in_check" = "$in_image" ] || fail "check.sh clones '$in_check', the Dockerfile '$in_image'"
}
t "check.sh and the Dockerfile name the same sandbox repository" sandbox_repository

image_tag() {
  OUT=""
  # The sandbox's source sits beside setup/ in the course project only.
  devcontainer="$root/../sandbox/devcontainer.json"
  [ -f "$devcontainer" ] || return 0
  in_compose="$(pin compose.yaml 's/^ *image: \(.*\)$/\1/p')"
  in_devcontainer="$(sed -n 's/^ *"image": "\(.*\)",$/\1/p' "$devcontainer" | head -n 1)"
  [ -n "$in_compose" ] || fail "no image in compose.yaml"
  [ "$in_compose" = "$in_devcontainer" ] || fail "compose.yaml uses '$in_compose', devcontainer.json '$in_devcontainer'"
}
t "compose.yaml and the sandbox's devcontainer.json name the same image" image_tag

finish
