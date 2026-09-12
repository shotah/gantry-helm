# gantry-helm — common operator commands
# Usage: make <target>

SWIFT       ?= swift
COVERAGE_MIN ?= 70
COVERAGE_JSON ?= .build/coverage.json
COVERAGE_SVG ?= badges/coverage.svg
BUMP ?= patch

.PHONY: help
help: ## Show available targets
	@echo
	@echo gantry-helm targets:
	@echo "  make test            Script tests + Mailbox Swift tests"
	@echo "  make test-scripts    Semver + badge + release + hooks + helm-bake (no Swift)"
	@echo "  make test-app        swift test (Mailbox)"
	@echo "  make coverage       llvm-cov JSON + 70% Mailbox bar"
	@echo "  make check-app       test + coverage"
	@echo "  make check           script tests + check-app"
	@echo "  make ios             xcodebuild (macOS only, CODE_SIGNING_ALLOWED=NO)"
	@echo "  make install-hooks   Pre-commit: tests. Pre-push: coverage."
	@echo "  make version         Show VERSION + next tag (dry-run)"
	@echo "  make release         Bump tag + latest, update VERSION, push"
	@echo "  make clean           Remove .build"
	@echo
	@echo "Mailbox tests run on Linux and macOS (swift test). The IPA needs Xcode."
	@echo

.PHONY: all
all: check

.PHONY: test-scripts
test-scripts: ## Semver + coverage-badge + release + hooks + bake (no Swift toolchain)
	./test/scripts/semver.test.sh
	./test/scripts/coverage-badge.test.sh
	./test/scripts/release.test.sh
	./test/scripts/hooks.test.sh
	./test/scripts/helm-bake.test.sh

.PHONY: test-app
test-app: ## Mailbox Swift tests
	$(SWIFT) test

.PHONY: test
test: test-scripts test-app ## Script tests + Mailbox tests

.PHONY: coverage
coverage: ## llvm-cov JSON + 70% bar
	$(SWIFT) test --enable-code-coverage
	./scripts/coverage-export.sh "$(COVERAGE_JSON)"
	@$(MAKE) coverage-gate

.PHONY: coverage-gate
coverage-gate: ## Fail if Mailbox line coverage is below COVERAGE_MIN (70)
	@test -f "$(COVERAGE_JSON)" || (echo "missing $(COVERAGE_JSON); run make coverage" >&2; exit 1)
	COVERAGE_MIN="$(COVERAGE_MIN)" ./scripts/coverage-gate.sh "$(COVERAGE_JSON)"

.PHONY: coverage-badge
coverage-badge: coverage ## Write badges/coverage.svg
	mkdir -p badges
	./scripts/coverage-badge.sh "$(COVERAGE_JSON)" "$(COVERAGE_SVG)"

.PHONY: check-app
check-app: coverage ## Mailbox tests + 70% coverage

.PHONY: check
check: test-scripts check-app ## Script tests + Mailbox tests + 70% coverage

.PHONY: ios
ios: ## Build the iOS app unsigned (needs Xcode)
	@command -v xcodebuild >/dev/null || (echo "xcodebuild not on PATH — open app/Helm.xcodeproj on a Mac" >&2; exit 1)
	xcodebuild -project app/Helm.xcodeproj -scheme Helm -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

.PHONY: ci
ci: check ## Local stand-in for CI checks

.PHONY: install-hooks
install-hooks: ## Install pre-commit (tests) and pre-push (coverage)
	@top=$$(git rev-parse --show-toplevel 2>/dev/null); \
	here=$$(cd "$(dir $(abspath $(lastword $(MAKEFILE_LIST))))" && pwd); \
	if [ -z "$$top" ] || [ "$$top" != "$$here" ]; then \
	  echo "init this folder as its own git checkout first (like repos/gantry-cab)" >&2; \
	  echo "git root is $${top:-"(none)"}" >&2; \
	  exit 1; \
	fi
	cp scripts/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	cp scripts/pre-push .git/hooks/pre-push
	chmod +x .git/hooks/pre-push
	@echo "Installed .git/hooks/pre-commit and pre-push"

.PHONY: version
version: ## Show VERSION file and next tag (dry-run)
	@echo "VERSION $$(tr -d '[:space:]' < VERSION)"
	@DRY_RUN=1 ./scripts/release.sh

.PHONY: release
release: ## Bump version + latest tags, update VERSION, push (BUMP=patch|minor|major)
	BUMP="$(BUMP)" TAG="$(TAG)" DRY_RUN="$(DRY_RUN)" SKIP_PUSH="$(SKIP_PUSH)" ALLOW_DIRTY="$(ALLOW_DIRTY)" ./scripts/release.sh

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf .build badges app/build DerivedData

.DEFAULT_GOAL := help
