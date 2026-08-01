#!/usr/bin/env bash
# One-time (idempotent) setup of the containerized powerbash dev environment.
# Uses toolbox if present (native on Fedora Atomic/Silverblue/Bluefin), falling
# back to distrobox otherwise. Both are thin wrappers around Podman and both
# bind-mount $HOME automatically, so the repo is visible inside the container
# at the same path with no manual volume config.
set -euo pipefail

CONTAINER_NAME="powerbash-dev"
IMAGE_NAME="powerbash-dev:latest"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINERFILE="${REPO_ROOT}/dev/Containerfile"

if command -v toolbox >/dev/null 2>&1; then
    ENGINE="toolbox"
elif command -v distrobox >/dev/null 2>&1; then
    ENGINE="distrobox"
else
    echo "Neither toolbox nor distrobox found. Install one of them first." >&2
    exit 1
fi

echo "Using ${ENGINE} to build the dev container..."
podman build -t "${IMAGE_NAME}" -f "${CONTAINERFILE}" "${REPO_ROOT}/dev"

if [ "${ENGINE}" = "toolbox" ]; then
    if ! toolbox list --containers | grep -q "${CONTAINER_NAME}"; then
        toolbox create --image "${IMAGE_NAME}" --container "${CONTAINER_NAME}" -y
    fi
    toolbox run --container "${CONTAINER_NAME}" \
        bash -lc "cd '${REPO_ROOT}' && shellcheck powerbash.sh && ./tests/smoke.sh"
else
    if ! distrobox list | grep -q "${CONTAINER_NAME}"; then
        distrobox create --image "${IMAGE_NAME}" --name "${CONTAINER_NAME}" --yes
    fi
    distrobox enter "${CONTAINER_NAME}" -- \
        bash -lc "cd '${REPO_ROOT}' && shellcheck powerbash.sh && ./tests/smoke.sh"
fi

echo
echo "Done. Enter the container with ./dev/toolbox-enter.sh"
