# powerbash development tasks.
#
# Every target here is a thin wrapper around a script that still works on its
# own -- nothing is implemented in the Makefile itself. CI calls these same
# targets, so a wrapper that drifts away from what the scripts do gets caught
# on the next push rather than the next time someone reads the README.
#
# `make check` is the whole of CI except the macOS and dash jobs, which need
# runners this repo cannot provide locally.

# Which bash runs the suite. CI pins this to /bin/bash on macOS, where that is
# 3.2.57 and the Homebrew bash on PATH would not be.
BASH ?= bash

SHELLCHECK_TARGETS := powerbash.sh tests/*.sh dev/*.sh dev/bashrc

CONTAINER := powerbash-dev
IMAGE := powerbash-dev:latest

.DEFAULT_GOAL := help

.PHONY: help lint test test-bash32 check toolbox shell toolbox-clean version

help: ## Show this message
	@echo "powerbash $$(sed -n 's/^POWERBASH_VERSION=\"\(.*\)\"$$/\1/p' powerbash.sh)"
	@echo
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'
	@echo
	@echo "  BASH=/path/to/bash    run the suite under a specific bash"

lint: ## shellcheck the script, the tests, and the dev scripts
	shellcheck $(SHELLCHECK_TARGETS)

test: ## Run the smoke test (BASH=... picks the interpreter)
	$(BASH) tests/smoke.sh

test-bash32: ## Run the smoke test under bash 3.2, in a container
	./dev/test-bash32.sh

check: lint test test-bash32 ## Everything CI runs that can run locally

toolbox: ## Build the dev container and create it (one time)
	./dev/toolbox-setup.sh

shell: ## Enter the dev container, running the working copy of the prompt
	./dev/toolbox-enter.sh

toolbox-clean: ## Remove the dev container and its image
	-toolbox rm -f $(CONTAINER) 2>/dev/null || distrobox rm -f $(CONTAINER) 2>/dev/null
	-podman rmi -f $(IMAGE) 2>/dev/null

version: ## Print the version the script declares
	@sed -n 's/^POWERBASH_VERSION="\(.*\)"$$/\1/p' powerbash.sh
