#!/usr/bin/env bash
# check.sh: checks a laptop's setup for the QCon SF workshop "Effective
# AI-native Development with Harness Engineering", and prints a summary to
# send to the presenters.
#
# Usage:   bash check.sh
# Options: --no-model   skip the one model call
#          --no-app     don't start PetClinic
#
# Environment:
#   HE_SANDBOX_DIR   the sandbox clone (default: ../petclinic, beside this
#                    repository; compose.yaml reads the same variable)
#   HE_APP_PORT      the laptop port PetClinic is published on (default: 8080)
#
# It checks Docker, the workshop image and the sandbox clone on the laptop,
# then runs he-check in the workshop container. That half compiles the sandbox
# offline (which writes target/ in the clone), starts and stops PetClinic, and
# asks the model for one word. It never prints keys, tokens or environment
# variables, and it shows your home folder as ~.
#
# Exit status: 0 when nothing failed, 1 when at least one check failed.
#
# Written for bash 3.2, the version macOS ships.

set -u

SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX_DIR="${HE_SANDBOX_DIR:-$(dirname "$SETUP_DIR")/petclinic}"
# The sandbox's pinned commit and the repository it is cloned from.
# HE_SANDBOX_COMMIT overrides the commit, for the presenters' own tests.
SANDBOX_COMMIT="${HE_SANDBOX_COMMIT:-705e5608c68e43743251494d57150bdfc087eb47}"
SANDBOX_REMOTE="qcon-ai-native-development/petclinic"
SANDBOX_URL="https://github.com/qcon-ai-native-development/petclinic.git"
APP_PORT="${HE_APP_PORT:-8080}"

INSIDE_OPTS=""
APP=1
for arg in "$@"; do
  case "$arg" in
    --no-model) INSIDE_OPTS="$INSIDE_OPTS --no-model" ;;
    --no-app) INSIDE_OPTS="$INSIDE_OPTS --no-app"; APP=0 ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'check.sh: unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

PASS=0
WARN=0
FAIL=0
SUMMARY=""
TILDE="~"

# result STATUS LABEL DETAIL
result() {
  case "$1" in
    PASS) PASS=$((PASS + 1)) ;;
    WARN) WARN=$((WARN + 1)) ;;
    FAIL) FAIL=$((FAIL + 1)) ;;
  esac
  # Show the home folder as ~, so the summary carries no user name. The ~
  # comes from a variable: bash 3.2 and 5 treat a literal \~ in the
  # replacement differently.
  detail="${3//"$HOME"/$TILDE}"
  printf '%-4s  %-16s %s\n' "$1" "$2" "$detail"
  if [ "$1" != PASS ]; then
    SUMMARY="${SUMMARY}${1} ${2}: ${detail}
"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

compose() { docker compose -f "$SETUP_DIR/compose.yaml" "$@"; }

# --- Platform ----------------------------------------------------------------

os="$(uname -s)"
arch="$(uname -m)"
native_linux=0
case "$os" in
  Darwin)
    platform="macOS $(sw_vers -productVersion 2>/dev/null || echo '?') $arch"
    result PASS platform "$platform" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      if grep -qi 'microsoft-standard' /proc/version 2>/dev/null || [ -n "${WSL_INTEROP:-}" ]; then
        platform="WSL 2 $arch"
        result PASS platform "$platform"
      else
        platform="WSL 1 $arch"
        result FAIL platform "WSL 1 is not supported. Convert the distribution with 'wsl --set-version <name> 2' in PowerShell"
      fi
      case "$SETUP_DIR" in
        /mnt/*) result WARN location "$SETUP_DIR is on the Windows drive, which is slow from WSL. Use a folder in your Linux home" ;;
      esac
    else
      # shellcheck disable=SC1091 # a system file, read at run time
      distro="$( (. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-Linux}") || echo Linux)"
      platform="$distro $arch"
      native_linux=1
      result PASS platform "$platform"
    fi ;;
  *)
    platform="$os $arch"
    result FAIL platform "$os is not supported. On Windows, use WSL 2" ;;
esac

# On Linux without Docker Desktop, files keep their owner inside the
# container, and the container works as user id 1000.
if [ "$native_linux" -eq 1 ]; then
  uid="$(id -u 2>/dev/null || echo 1000)"
  if [ "$uid" != 1000 ]; then
    result WARN user "your user id is $uid, and the container works as 1000, so it may not be able to write to the sandbox. See 'Linux with another user id' in the README"
  fi
fi

# --- Disk --------------------------------------------------------------------

free_kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 {print $4}')"
if [ -n "$free_kb" ]; then
  free_gb=$((free_kb / 1048576))
  if [ "$free_gb" -ge 10 ]; then
    result PASS disk "${free_gb} GB free in $HOME"
  else
    result WARN disk "${free_gb} GB free in $HOME. 10 GB or more is recommended"
  fi
fi

# --- Docker ------------------------------------------------------------------

DOCKER=0
docker_version=""
if ! have docker; then
  result FAIL docker "docker not found. Install Docker (see the README), or use the Codespaces path"
elif ! docker_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null)" || [ -z "$docker_version" ]; then
  result FAIL docker "Docker is installed but not running. Start Docker and run the check again"
elif ! compose_version="$(docker compose version --short 2>/dev/null)" || [ -z "$compose_version" ]; then
  result FAIL docker "Docker $docker_version has no Compose v2 ('docker compose'). Install the Compose plugin"
else
  result PASS docker "$docker_version, compose $compose_version"
  DOCKER=1
fi

if [ "$DOCKER" -eq 1 ]; then
  mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
  case "$mem_bytes" in
    ''|*[!0-9]*) mem_bytes=0 ;;
  esac
  if [ "$mem_bytes" -gt 0 ]; then
    mem_gb=$(((mem_bytes + 536870912) / 1073741824))
    if [ "$mem_gb" -ge 4 ]; then
      result PASS docker-memory "${mem_gb} GB"
    else
      result WARN docker-memory "${mem_gb} GB. Give Docker 4 GB or more in its settings; Maven and the agent need room"
    fi
  fi
fi

# --- Image -------------------------------------------------------------------

image=""
image_tag="unknown"
if [ "$DOCKER" -eq 1 ]; then
  image="$(compose config --images 2>/dev/null | head -n 1)"
  if [ -z "$image" ]; then
    result FAIL image "could not read the image name from $SETUP_DIR/compose.yaml"
  else
    image_tag="${image##*:}"
    if docker image inspect "$image" >/dev/null 2>&1; then
      result PASS image "$image_tag"
    else
      result FAIL image "$image is not on this machine. Run: docker compose pull"
    fi
  fi
fi

# --- Sandbox -----------------------------------------------------------------

if [ ! -d "$SANDBOX_DIR" ] || ! have git || ! git -C "$SANDBOX_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  result FAIL sandbox "no clone of the sandbox in $SANDBOX_DIR. Run: git clone $SANDBOX_URL $SANDBOX_DIR"
else
  head="$(git -C "$SANDBOX_DIR" rev-parse HEAD 2>/dev/null)"
  url="$(git -C "$SANDBOX_DIR" config --get remote.origin.url 2>/dev/null || true)"
  case "$url" in
    *"$SANDBOX_REMOTE"*) ;;
    *) result WARN sandbox "origin is '${url:-none}', expected $SANDBOX_REMOTE" ;;
  esac
  if [ "$head" != "$SANDBOX_COMMIT" ]; then
    result FAIL sandbox "on commit ${head:0:7}, expected ${SANDBOX_COMMIT:0:7}. Run: git -C $SANDBOX_DIR pull"
  else
    # Build output is ignored by the sandbox's .gitignore, so it does not
    # count as a change here.
    changes="$(git -C "$SANDBOX_DIR" --no-optional-locks status --porcelain 2>/dev/null | head -n 1)"
    if [ -n "$changes" ]; then
      result WARN sandbox "commit ${head:0:7}, with local changes. Run: git -C $SANDBOX_DIR status"
    else
      result PASS sandbox "commit ${head:0:7}, no local changes"
    fi
  fi
fi

# --- Container ---------------------------------------------------------------

RUNNING=0
if [ "$DOCKER" -eq 1 ]; then
  if [ -n "$(compose ps --status running -q workshop 2>/dev/null)" ]; then
    result PASS container "the workshop container is running"
    RUNNING=1
  else
    result FAIL container "the workshop container is not running. Run: docker compose up -d"
  fi
fi

# --- The container half ------------------------------------------------------

# he-check prints the same kind of lines as this script. They are shown as
# they are and counted here, so the summary covers both halves.
app_started=0
if [ "$RUNNING" -eq 1 ]; then
  # shellcheck disable=SC2086 # the options are separate words on purpose
  inside="$(compose exec -T workshop he-check --from-host $INSIDE_OPTS 2>&1 </dev/null)"
  seen=0
  while IFS= read -r line; do
    case "$line" in
      PASS\ *|WARN\ *|FAIL\ *)
        status="${line%% *}"
        rest="${line#"$status"}"
        rest="${rest#"${rest%%[! ]*}"}"
        label="${rest%% *}"
        detail="${rest#"$label"}"
        detail="${detail#"${detail%%[! ]*}"}"
        result "$status" "$label" "$detail"
        seen=$((seen + 1))
        if [ "$label" = app ] && [ "$status" = PASS ]; then app_started=1; fi ;;
    esac
  done <<EOF
$inside
EOF
  if [ "$seen" -eq 0 ]; then
    first="$(printf '%s' "$inside" | head -n 1 | cut -c1-120)"
    result FAIL container-check "he-check did not run in the container (${first:-no output}). Run: docker compose pull, then docker compose up -d"
  fi
fi

# --- Published port ----------------------------------------------------------

# PetClinic answers inside the container. This tests that the laptop reaches
# it through the published port, as a browser will in the workshop.
if [ "$RUNNING" -eq 1 ] && [ "$APP" -eq 1 ]; then
  if [ "$app_started" -eq 1 ]; then
    if ! have curl; then
      result WARN port "curl not found, so http://localhost:$APP_PORT was not tested from the laptop"
    else
      code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://localhost:$APP_PORT" 2>/dev/null)" || true
      if [ "$code" = 200 ]; then
        result PASS port "PetClinic answers on http://localhost:$APP_PORT"
      else
        result FAIL port "PetClinic runs in the container, but http://localhost:$APP_PORT does not answer on the laptop. Another program may hold port $APP_PORT; see 'Port 8080 is taken' in the README"
      fi
    fi
  fi
  compose exec -T workshop he-check --stop-app >/dev/null 2>&1 </dev/null || true
fi

# --- Summary -----------------------------------------------------------------

echo
echo "Paste the block below into your reply:"
echo
echo '```'
printf 'workshop check, %s, %s, docker %s\n' "$(date '+%Y-%m-%d %H:%M')" "$platform" "${docker_version:-none}"
echo 'path: local docker'
printf 'image: %s\n' "$image_tag"
printf '%s pass, %s warn, %s fail\n' "$PASS" "$WARN" "$FAIL"
printf '%s' "$SUMMARY"
echo '```'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
