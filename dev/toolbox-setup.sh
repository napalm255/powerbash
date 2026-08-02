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

# A container created from an older build of the image keeps running that
# older build forever: rebuilding the image does not touch it. That silently
# hands you a container missing whatever the Containerfile just added, so
# compare image IDs and recreate when they differ. Both toolbox and distrobox
# are podman underneath, so one inspect covers both.
container_is_stale() {
    local running built
    running="$(podman inspect --format '{{.Image}}' "${CONTAINER_NAME}" 2>/dev/null || true)"
    [ -n "${running}" ] || return 1
    built="$(podman image inspect --format '{{.Id}}' "${IMAGE_NAME}" 2>/dev/null || true)"
    [ -n "${built}" ] || return 1
    [ "${running}" != "${built}" ]
}

if container_is_stale; then
    echo "Container '${CONTAINER_NAME}' was built from an older image; recreating it."
    if [ "${ENGINE}" = "toolbox" ]; then
        toolbox rm -f "${CONTAINER_NAME}"
    else
        distrobox rm -f "${CONTAINER_NAME}"
    fi
fi

VERIFY="cd '${REPO_ROOT}' && make lint && make test"

if [ "${ENGINE}" = "toolbox" ]; then
    if ! toolbox list --containers | grep -q "${CONTAINER_NAME}"; then
        toolbox create --image "${IMAGE_NAME}" --container "${CONTAINER_NAME}" -y
    fi
    toolbox run --container "${CONTAINER_NAME}" bash -lc "${VERIFY}"
else
    if ! distrobox list | grep -q "${CONTAINER_NAME}"; then
        distrobox create --image "${IMAGE_NAME}" --name "${CONTAINER_NAME}" --yes
    fi
    distrobox enter "${CONTAINER_NAME}" -- bash -lc "${VERIFY}"
fi

echo
echo "Done. Enter the container with ./dev/toolbox-enter.sh"
