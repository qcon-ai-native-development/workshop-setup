# shellcheck shell=bash
# Shared helpers for the check tests. Sourced by he-check-test.sh and
# check-test.sh. Each test runs the real script with stub commands first on the
# PATH, then asserts on the script's output and exit status.

TESTS=0
FAILED=0
OUT=""
STATUS=0

# run CMD...: runs a command, keeps its combined output and exit status.
run() {
  OUT="$("$@" 2>&1)"
  STATUS=$?
}

fail() {
  FAILED=$((FAILED + 1))
  printf 'not ok: %s\n    %s\n' "$CURRENT" "$1"
  printf '%s\n' "$OUT" | sed 's/^/    | /'
}

# has_line REGEX: some output line matches the extended regex.
has_line() {
  if ! printf '%s\n' "$OUT" | grep -Eq -- "$1"; then
    fail "expected a line matching: $1"
    return 1
  fi
}

no_line() {
  if printf '%s\n' "$OUT" | grep -Eq -- "$1"; then
    fail "expected no line matching: $1"
    return 1
  fi
}

exits() {
  if [ "$STATUS" -ne "$1" ]; then
    fail "expected exit status $1, got $STATUS"
    return 1
  fi
}

# t NAME FUNCTION: runs one test in a fresh state folder.
t() {
  CURRENT="$1"
  TESTS=$((TESTS + 1))
  before=$FAILED
  STATE="$(mktemp -d)"
  export STATE
  "$2"
  rm -rf "$STATE"
  [ "$FAILED" -eq "$before" ] && printf 'ok: %s\n' "$CURRENT"
}

finish() {
  printf '%s tests, %s failed\n' "$TESTS" "$FAILED"
  [ "$FAILED" -eq 0 ]
}
