#!/usr/bin/env bash
# Run the smoke test against bash 3.2 -- the oldest bash powerbash supports,
# and the one macOS still ships as /bin/bash.
#
# Uses the official bash:3.2 image rather than building 3.2.57 from source:
# old bash does not compile cleanly against modern glibc, and the image is
# what CI's bash32 job uses too, so local and CI results match.
#
# Podman by default, Docker as a fallback.
set -euo pipefail

IMAGE="docker.io/library/bash:3.2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
    MOUNT_OPTS=":ro,Z"
elif command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
    MOUNT_OPTS=":ro"
else
    echo "Neither podman nor docker found. Install one of them first." >&2
    exit 1
fi

exec "${ENGINE}" run --rm \
    -v "${REPO_ROOT}:/src${MOUNT_OPTS}" \
    -w /src \
    "${IMAGE}" \
    sh -c '
        apk add --no-cache git ncurses >/dev/null &&
        bash --version | head -1 &&
        bash /src/tests/smoke.sh
    '
