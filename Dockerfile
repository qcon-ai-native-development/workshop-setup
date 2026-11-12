# The workshop image: plain Claude Code and OpenCode, JDK 17, and PetClinic's
# Maven dependencies already downloaded.
#
# Plain means no managed settings: the sandbox repository's own agent
# configuration loads once its folder is trusted. Attendees build their harness
# in the repository, so the repository is in control.
#
# Built with the setup repository's root as context:
#   docker build -t ghcr.io/qcon-ai-native-development/workshop:<tag> --build-arg IMAGE_TAG=<tag> .

ARG BASE_IMAGE=node:22-bookworm-slim
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

ARG CLAUDE_CODE_VERSION=2.1.281
ARG OPENCODE_VERSION=1.18.32

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8

# JDK 17 for PetClinic; the Maven wrapper in the sandbox brings Maven itself.
# The slim base has no git or curl. The rest is what an agent reaches for:
# search, JSON, a pager, process tools.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless ca-certificates git curl ripgrep jq python3 less procps \
 && git config --system --add safe.directory '*' \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
      "opencode-ai@${OPENCODE_VERSION}" \
 && npm cache clean --force \
 && claude --version \
 && opencode --version

# The folders that compose.yaml mounts volumes on. They exist in the image and
# belong to node, so a new named volume starts with the right owner, and with
# the Maven dependencies below.
RUN mkdir -p /work /home/node/.claude /home/node/.m2 /home/node/.cache \
      /home/node/.config/opencode /home/node/.local/share/opencode \
 && chown -R node:node /work /home/node

# The base image defines node, with user id 1000.
# hadolint ignore=DL3066
USER node

# PetClinic's dependencies, downloaded once here so that nothing is downloaded
# over the venue's network. The sandbox is cloned at a pinned commit, built
# with its tests (which fetches the test runner too), and deleted; only
# ~/.m2 stays. "clean" is there because agents often run it, and it needs a
# plugin of its own. The two database tests need Docker and skip themselves.
#
# SANDBOX_COMMIT is the sandbox's starting state, the commit check.sh expects.
# SANDBOX_DEPS_COMMIT is the sandbox's image-deps branch: the starting state
# plus every dependency the day's later steps add. That is the commit built
# here, so those steps build without the network too.
#
# This is the last large layer. A new dependencies commit rebuilds it and
# nothing above it.
ARG SANDBOX_REPO=https://github.com/qcon-ai-native-development/petclinic.git
ARG SANDBOX_COMMIT=4f8a4504a308fd32147e525f0154b153d425ea2d
ARG SANDBOX_DEPS_COMMIT=dbfaf89a8ca165a7dbe6144ae89881fd00d50c8e
RUN git init -q /tmp/sandbox \
 && cd /tmp/sandbox \
 && git remote add origin "${SANDBOX_REPO}" \
 && git fetch -q --depth 1 origin "${SANDBOX_DEPS_COMMIT}" \
 && git checkout -q FETCH_HEAD \
 && ./mvnw -B -q clean verify \
 && ./mvnw -B -q -o spring-boot:help \
 && cd / \
 && rm -rf /tmp/sandbox

COPY --chmod=0755 image/he-check /usr/local/bin/he-check

# CLAUDE_CONFIG_DIR keeps all of Claude Code's state, .claude.json included, in
# the one folder that holds the sign-in. The pinned version stays: no updater.
ARG IMAGE_TAG=dev
ENV CLAUDE_CONFIG_DIR=/home/node/.claude \
    DISABLE_AUTOUPDATER=1 \
    HE_CLAUDE_VERSION=${CLAUDE_CODE_VERSION} \
    HE_IMAGE_TAG=${IMAGE_TAG} \
    DEBIAN_FRONTEND=

WORKDIR /work
CMD ["sleep", "infinity"]
