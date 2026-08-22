# ZenTomato — the only sanctioned way to build this project.
#
# WHY A MAKEFILE AT ALL
# Three of these steps must happen in a fixed order, and getting the order
# wrong fails in a confusing way rather than an obvious one:
#
#     .env  ──▶ Support/Secrets.xcconfig ──▶ ZenTomato.xcodeproj ──▶ build/test
#            (make secrets)              (make generate)
#
# `xcodegen generate` reads project.yml, which names Secrets.xcconfig as the
# target's configuration file — so XcodeGen FAILS if that file does not exist
# yet. And an .xcconfig is parsed when the project is loaded, so generating it
# after the project exists changes nothing about the current build. This file
# encodes that ordering once, and continuous integration calls these same
# targets, so local and CI cannot drift apart.
#
# NO XCODE GUI IS EVER REQUIRED. `make generate && make test` from a clean
# clone is the contract.

SHELL := /bin/bash

# --- Configuration ---------------------------------------------------------

# The simulator every build and test run targets. Pinned in ONE place so the
# device name exists exactly once in the repository. Override it from the
# environment or the command line if you prefer a different device:
#
#     make test DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
#
SIMULATOR_NAME ?= iPhone 17
SIMULATOR_DEVICE_TYPE ?= com.apple.CoreSimulator.SimDeviceType.iPhone-17
DESTINATION ?= platform=iOS Simulator,name=$(SIMULATOR_NAME),OS=latest

PROJECT := ZenTomato.xcodeproj
SCHEME := ZenTomato
DERIVED_DATA := DerivedData

# Simulator builds are never signed. Without these, a machine with no
# development team configured cannot build at all — and DEVELOPMENT_TEAM is
# deliberately optional in .env.
XCODEBUILD_FLAGS := \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-destination '$(DESTINATION)' \
	-derivedDataPath $(DERIVED_DATA) \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO

.DEFAULT_GOAL := help

.PHONY: help secrets generate simulator build test script-tests lint \
        check-todoist check-secrets checks ci hooks clean

# --- Entry points ----------------------------------------------------------

help: ## Show this help
	@echo "ZenTomato — make targets"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN { FS = ":.*?## " } { printf "  \033[1m%-16s\033[0m %s\n", $$1, $$2 }'
	@echo
	@echo "First time here:"
	@echo "  cp .env.example .env   # then fill it in"
	@echo "  make hooks             # enable the pre-commit checks"
	@echo "  make generate          # create ZenTomato.xcodeproj"
	@echo "  make test"
	@echo
	@echo "Simulator: $(DESTINATION)"

secrets: ## Regenerate Support/Secrets.xcconfig from .env
	@./scripts/gen-secrets.sh

generate: secrets ## Generate ZenTomato.xcodeproj from project.yml
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "make generate: xcodegen is not installed."; \
		echo "               brew install xcodegen"; \
		exit 1; \
	}
	@xcodegen generate --spec project.yml --quiet
	@echo "make generate: $(PROJECT) is current."

simulator: ## Create the pinned simulator if this machine does not have it
	@if ! xcrun simctl list devices | grep -q '^ *$(SIMULATOR_NAME) ('; then \
		echo "make simulator: creating '$(SIMULATOR_NAME)'…"; \
		runtime=$$(xcrun simctl list runtimes | awk '/^iOS /{ print $$NF }' | tail -1); \
		xcrun simctl create '$(SIMULATOR_NAME)' '$(SIMULATOR_DEVICE_TYPE)' "$$runtime" >/dev/null; \
	fi
	@echo "make simulator: '$(SIMULATOR_NAME)' is available."

build: generate simulator ## Build the app
	@xcodebuild build $(XCODEBUILD_FLAGS)

test: generate simulator ## Build and run the unit tests
	@xcodebuild test $(XCODEBUILD_FLAGS)

# --- The four gates --------------------------------------------------------
# Each is a script rather than a recipe body, because the pre-commit hook and
# the CI workflow run the identical script. A gate that is implemented twice is
# a gate that is enforced once.

lint: ## Run swiftlint --strict
	@./scripts/check-lint.sh

check-todoist: ## Fail if any Todoist endpoint is not on the allowlist
	@./scripts/check-todoist-writes.sh

check-secrets: ## Fail if a credential is in the tree
	@./scripts/check-secrets.sh

script-tests: ## Run the shell-level tests for the secrets and hook scripts
	@./scripts/tests/run-script-tests.sh

checks: lint check-todoist check-secrets script-tests ## Run every non-Xcode gate

ci: checks test ## Everything continuous integration runs, in the same order

# --- Housekeeping ----------------------------------------------------------

hooks: ## Enable the pre-commit hooks in .githooks
	@git config core.hooksPath .githooks
	@echo "make hooks: pre-commit hooks enabled (git config core.hooksPath .githooks)."
	@echo "            They run lint, the Todoist allowlist check, and the secret"
	@echo "            scan. Tests are left to CI — they are too slow for a commit."

clean: ## Remove build products and the generated project
	@rm -rf $(DERIVED_DATA) $(PROJECT)
	@echo "make clean: removed $(DERIVED_DATA) and $(PROJECT)."
	@echo "            Support/Secrets.xcconfig was kept; 'make secrets' rebuilds it."
