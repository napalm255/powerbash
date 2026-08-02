# powerbash development tasks.
#
# CI calls these same targets, so a target that stops matching what the
# project actually does fails on the next push rather than going stale in
# prose. `make check` is the whole of CI except the macOS and dash jobs,
# which need runners this repo cannot provide locally.
#
# The container plumbing lives in the recipes below rather than in scripts
# under dev/. Three files that each ran three commands were three files too
# many. What stays a file, and why:
#
#   tests/smoke.sh    The suite runs inside docker.io/library/bash:3.2, an
#                     Alpine image with no make in it -- make cannot be its
#                     entry point there. It is also 250 lines of bash full of
#                     $ and backticks (it tests PS1 injection), none of which
#                     survives Makefile escaping intact.
#   dev/bashrc        `bash --rcfile` takes a path, so it has to be one.
#   dev/Containerfile `podman build -f` takes a path too.
#
# Recipes are written for GNU make 3.81, which is what macOS ships: no
# .ONESHELL, so multi-step recipes are one backslash-continued shell line.

# Which bash runs the suite. CI pins this to /bin/bash on macOS, where that is
# 3.2.57 and the Homebrew bash on PATH would not be.
BASH ?= bash

SHELLCHECK_TARGETS := powerbash.sh tests/*.sh dev/bashrc

CONTAINER := powerbash-dev
IMAGE := powerbash-dev:latest
BASH32_IMAGE := docker.io/library/bash:3.2

.DEFAULT_GOAL := help

.PHONY: help lint test test-bash32 check toolbox shell toolbox-clean version

help: ## Show this message
	@echo "powerbash $$(sed -n 's/^POWERBASH_VERSION=\"\(.*\)\"$$/\1/p' powerbash.sh)"
	@echo
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'
	@echo
	@echo "  BASH=/path/to/bash    run the suite under a specific bash"

lint: ## shellcheck the script, the tests, and the container rcfile
	shellcheck $(SHELLCHECK_TARGETS)

test: ## Run the smoke test (BASH=... picks the interpreter)
	$(BASH) tests/smoke.sh

# macOS gives us bash 3.2.57, but only on one OS and only under BSD userland.
# This runs the same suite against 3.2 on Linux/musl. The official bash:3.2
# image is used rather than building 3.2.57 from source: old bash does not
# compile cleanly against modern glibc. git and ncurses are what the suite
# needs on top of bash itself.
test-bash32: ## Run the smoke test under bash 3.2, in a container
	@if command -v podman >/dev/null 2>&1; then \
	    engine=podman; mount="$(CURDIR):/src:ro,Z"; \
	elif command -v docker >/dev/null 2>&1; then \
	    engine=docker; mount="$(CURDIR):/src:ro"; \
	else \
	    echo "Neither podman nor docker found. Install one of them first." >&2; \
	    exit 1; \
	fi; \
	"$$engine" run --rm -v "$$mount" -w /src $(BASH32_IMAGE) \
	  sh -c 'apk add --no-cache git ncurses >/dev/null && bash --version | head -1 && bash /src/tests/smoke.sh'

check: lint test test-bash32 ## Everything CI runs that can run locally

# toolbox where it exists (native on Fedora Atomic/Silverblue/Bluefin),
# distrobox otherwise. Both are thin wrappers around podman and both bind
# mount $HOME, so the repo is visible inside at the same path with no volume
# config -- which is why the recipes below can just cd to $(CURDIR).
toolbox: ## Build the dev container and create it (one time)
	@set -e; \
	if command -v toolbox >/dev/null 2>&1; then engine=toolbox; \
	elif command -v distrobox >/dev/null 2>&1; then engine=distrobox; \
	else echo "Neither toolbox nor distrobox found. Install one of them first." >&2; exit 1; fi; \
	echo "Using $$engine to build the dev container..."; \
	podman build -t $(IMAGE) -f dev/Containerfile dev; \
	running=$$(podman inspect --format '{{.Image}}' $(CONTAINER) 2>/dev/null || true); \
	built=$$(podman image inspect --format '{{.Id}}' $(IMAGE)); \
	if [ -n "$$running" ] && [ "$$running" != "$$built" ]; then \
	    echo "Container $(CONTAINER) was built from an older image; recreating it."; \
	    $$engine rm -f $(CONTAINER); \
	    running=""; \
	fi; \
	if [ -z "$$running" ]; then \
	    if [ "$$engine" = toolbox ]; then \
	        toolbox create --image $(IMAGE) --container $(CONTAINER) -y; \
	    else \
	        distrobox create --image $(IMAGE) --name $(CONTAINER) --yes; \
	    fi; \
	fi; \
	if [ "$$engine" = toolbox ]; then \
	    toolbox run --container $(CONTAINER) bash -lc "cd '$(CURDIR)' && make lint && make test"; \
	else \
	    distrobox enter $(CONTAINER) -- bash -lc "cd '$(CURDIR)' && make lint && make test"; \
	fi; \
	echo; \
	echo "Done. Enter the container with 'make shell'."

# A container created from an older build of the image keeps running that
# older build forever -- rebuilding the image does not touch it -- which is
# why `toolbox` compares image IDs above rather than only checking existence.
shell: ## Enter the dev container, running the working copy of the prompt
	@if command -v toolbox >/dev/null 2>&1 && toolbox list --containers | grep -q $(CONTAINER); then \
	    exec toolbox enter $(CONTAINER) -- bash -lc "cd '$(CURDIR)' && exec bash --rcfile dev/bashrc"; \
	elif command -v distrobox >/dev/null 2>&1 && distrobox list | grep -q $(CONTAINER); then \
	    exec distrobox enter $(CONTAINER) -- bash -lc "cd '$(CURDIR)' && exec bash --rcfile dev/bashrc"; \
	else \
	    echo "Container $(CONTAINER) not found. Run 'make toolbox' first." >&2; \
	    exit 1; \
	fi

toolbox-clean: ## Remove the dev container and its image
	-@toolbox rm -f $(CONTAINER) 2>/dev/null || distrobox rm -f $(CONTAINER) 2>/dev/null || true
	-@podman rmi -f $(IMAGE) 2>/dev/null || true

version: ## Print the version the script declares
	@sed -n 's/^POWERBASH_VERSION="\(.*\)"$$/\1/p' powerbash.sh
