#!/usr/bin/env bash
# Enter the powerbash dev container created by toolbox-setup.sh, with the
# working copy of powerbash.sh already sourced -- so the prompt you are
# looking at is the one you are editing. See dev/bashrc for what the shell
# sets up.
set -euo pipefail

CONTAINER_NAME="powerbash-dev"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENTER_CMD="cd '${REPO_ROOT}' && exec bash --rcfile '${REPO_ROOT}/dev/bashrc'"

if command -v toolbox >/dev/null 2>&1 && toolbox list --containers | grep -q "${CONTAINER_NAME}"; then
    exec toolbox enter "${CONTAINER_NAME}" -- bash -lc "${ENTER_CMD}"
elif command -v distrobox >/dev/null 2>&1 && distrobox list | grep -q "${CONTAINER_NAME}"; then
    exec distrobox enter "${CONTAINER_NAME}" -- bash -lc "${ENTER_CMD}"
else
    echo "Container '${CONTAINER_NAME}' not found. Run ./dev/toolbox-setup.sh first." >&2
    exit 1
fi
