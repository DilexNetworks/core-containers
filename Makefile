DEFAULT_GOAL := help
BIN_DIR := $(HOME)/bin
WRAPPER_DIR := wrappers

# Versioning / releases
# - Version is stored in VERSION (semver like 0.1.0)
# - `make release RELEASE=patch|minor|major` will bump, commit, tag, push, and create a GitHub release (if `gh` is installed)
VERSION_FILE := VERSION
RELEASE_PREFIX ?= v
DEFAULT_VERSION ?= 0.1.0

# Release controls
# - Set DRY_RUN=1 to preview commands without changing anything
DRY_RUN ?= 0

# Image tags (single source of truth)
HUGO_IMAGE := wyllie/hugo:hugo0.154.2-sass1.97.1-alpine3.23.2-1
AWS_IMAGE := wyllie/aws-cli:awscli2.32.7-alpine3.23.2-1
CDK_IMAGE := wyllie/cdk:awscli2.32.7-alpine3.23.2-1
CI_BASE_IMAGE := wyllie/ci-base:alpine3.23.2-1
PYTHON_IMAGE := wyllie/python:python3-alpine3.23.2-1
LATEX_IMAGE := wyllie/latex:alpine3.23.2-texlive-1

# Local test tags (for fast iteration without waiting on GitHub Actions)
CI_BASE_LOCAL := wyllie/ci-base:local
PYTHON_LOCAL := wyllie/python:local
HUGO_LOCAL := wyllie/hugo:local
AWS_LOCAL := wyllie/aws-cli:local
CDK_LOCAL := wyllie/cdk:local
LATEX_LOCAL := wyllie/latex:local

# Docker build platforms (used only by buildx targets)
PLATFORMS ?= linux/amd64,linux/arm64

.PHONY: install uninstall check-bin \
	build-ci-base build-python build-hugo build-aws build-cdk build-latex \
	build-all buildx-ci-base buildx-python buildx-hugo buildx-aws buildx-cdk buildx-latex \
	smoke-python smoke-hugo smoke-aws smoke-cdk \
	pull-published pull-ci-base pull-python pull-hugo pull-aws pull-cdk pull-latex images-info \
	version-init version-show version-set bump-version release commit-release tag-release push-release gh-release help

check-bin:
	@mkdir -p $(BIN_DIR)

install: check-bin
	@echo "Installing docker-backed CLI wrappers into $(BIN_DIR)"
	@sed "s|@@HUGO_IMAGE@@|$(HUGO_IMAGE)|g" $(WRAPPER_DIR)/hugo > $(BIN_DIR)/hugo
	@sed "s|@@AWS_IMAGE@@|$(AWS_IMAGE)|g" $(WRAPPER_DIR)/aws > $(BIN_DIR)/aws
	@sed "s|@@CDK_IMAGE@@|$(CDK_IMAGE)|g" $(WRAPPER_DIR)/cdk > $(BIN_DIR)/cdk
	@chmod +x $(BIN_DIR)/hugo $(BIN_DIR)/aws $(BIN_DIR)/cdk
	@echo "✔ Installed: hugo, aws, cdk"

uninstall:
	@echo "Removing docker-backed CLI wrappers from $(BIN_DIR)"
	@rm -f $(BIN_DIR)/hugo $(BIN_DIR)/aws $(BIN_DIR)/cdk
	@echo "✔ Removed"


# -----------------------------
# Local build targets (single-arch, fast)
# -----------------------------

build-ci-base:
	docker build -t $(CI_BASE_LOCAL) images/ci-base

build-python: build-ci-base
	docker build -t $(PYTHON_LOCAL) images/python

build-hugo: build-ci-base
	docker build -t $(HUGO_LOCAL) images/hugo

build-aws: build-ci-base
	docker build -t $(AWS_LOCAL) images/aws-cli

build-cdk: build-aws
	docker build -t $(CDK_LOCAL) images/cdk

build-latex: build-ci-base
	docker build -t $(LATEX_LOCAL) images/latex

build-all: build-ci-base build-python build-hugo build-aws build-cdk build-latex


# -----------------------------
# Local buildx targets (multi-arch, closer to CI)
# Notes:
# - `--load` can only load one arch into the local docker engine; buildx will still validate both.
# - Use `--push` to publish multi-arch manifests.
# -----------------------------

buildx-ci-base:
	docker buildx build --platform $(PLATFORMS) -t $(CI_BASE_LOCAL) --load images/ci-base

buildx-python: buildx-ci-base
	docker buildx build --platform $(PLATFORMS) -t $(PYTHON_LOCAL) --load images/python

buildx-hugo: buildx-ci-base
	docker buildx build --platform $(PLATFORMS) -t $(HUGO_LOCAL) --load images/hugo

buildx-aws: buildx-ci-base
	docker buildx build --platform $(PLATFORMS) -t $(AWS_LOCAL) --load images/aws-cli

buildx-cdk: buildx-aws
	docker buildx build --platform $(PLATFORMS) -t $(CDK_LOCAL) --load images/cdk

buildx-latex: buildx-ci-base
	docker buildx build --platform $(PLATFORMS) -t $(LATEX_LOCAL) --load images/latex


# -----------------------------
# Smoke tests (run local tags)
# -----------------------------

smoke-python: build-python
	docker run --rm $(PYTHON_LOCAL) python --version
	docker run --rm $(PYTHON_LOCAL) pip --version

smoke-hugo: build-hugo
	docker run --rm $(HUGO_LOCAL) hugo version
	docker run --rm $(HUGO_LOCAL) sass --version

smoke-aws: build-aws
	docker run --rm $(AWS_LOCAL) aws --version

smoke-cdk: build-cdk
	docker run --rm $(CDK_LOCAL) cdk version
	docker run --rm $(CDK_LOCAL) aws --version


# -----------------------------
# Pull published images (pinned tags used by wrappers)
# -----------------------------

images-info:
	@echo "Published images (wrappers use these):"
	@echo "  ci-base   : $(CI_BASE_IMAGE)"
	@echo "  python    : $(PYTHON_IMAGE)"
	@echo "  hugo      : $(HUGO_IMAGE)"
	@echo "  aws-cli   : $(AWS_IMAGE)"
	@echo "  cdk       : $(CDK_IMAGE)"

pull-ci-base:
	docker pull $(CI_BASE_IMAGE)

pull-python:
	docker pull $(PYTHON_IMAGE)

pull-hugo:
	docker pull $(HUGO_IMAGE)

pull-aws:
	docker pull $(AWS_IMAGE)

pull-cdk:
	docker pull $(CDK_IMAGE)

pull-latex:
	docker pull $(LATEX_IMAGE)

pull-published: pull-ci-base pull-python pull-hugo pull-aws pull-cdk pull-latex
	@echo "✔ Pulled published images"


# -----------------------------
# Versioning / Release (manual)
# -----------------------------

# Ensure we have a version file.
version-init:
	@if [ ! -f "$(VERSION_FILE)" ]; then \
		echo "$(DEFAULT_VERSION)" > "$(VERSION_FILE)"; \
		echo "✔ Created $(VERSION_FILE) with $(DEFAULT_VERSION)"; \
	fi

# Print the current version (e.g., 0.1.0)
version-show: version-init
	@cat "$(VERSION_FILE)"

# Set version explicitly: `make version-set VERSION=0.2.0`
version-set:
	@[ -n "$(VERSION)" ] || { echo "❌ VERSION is required (e.g., make version-set VERSION=0.2.0)"; exit 2; }
	@echo "$(VERSION)" > "$(VERSION_FILE)"
	@echo "✔ Set version to $(VERSION)"

# Bump semver in VERSION Usage: `make bump-version RELEASE=patch|minor|major`
# (Bump semantics are handled by bump2version: patch|minor|major)
bump-version: version-init
	@[ -n "$(RELEASE)" ] || { echo "❌ RELEASE is required (patch|minor|major)"; exit 2; }
	@command -v bump2version >/dev/null 2>&1 || { echo "❌ bump2version is required but not found. Install it (pipx/pip) and try again."; exit 2; }
	@# Bump version using bump2version, but let this Makefile handle commit/tag.
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "DRY_RUN bump2version --no-commit --no-tag $(RELEASE)"; \
	else \
		bump2version --no-commit --no-tag "$(RELEASE)"; \
	fi
	@echo "✔ Bumped version to $$(cat "$(VERSION_FILE)")"

# Commit the version bump.
commit-release: version-init
	@V=$$(cat "$(VERSION_FILE)" | tr -d ' \t\n\r'); \
	[ -n "$$V" ] || { echo "❌ $(VERSION_FILE) is empty"; exit 2; }; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		echo "DRY_RUN git add $(VERSION_FILE)"; \
		if [ -f .bumpversion.cfg ]; then echo "DRY_RUN git add .bumpversion.cfg"; fi; \
		echo "DRY_RUN git commit -m 'chore(release): $(RELEASE_PREFIX)$$V'"; \
	else \
		git add "$(VERSION_FILE)"; \
		if [ -f .bumpversion.cfg ]; then git add .bumpversion.cfg; fi; \
		git commit -m "chore(release): $(RELEASE_PREFIX)$$V"; \
	fi

# Create a lightweight git tag (e.g., v0.1.1)
tag-release: version-init
	@V=$$(cat "$(VERSION_FILE)" | tr -d ' \t\n\r'); \
	TAG="$(RELEASE_PREFIX)$$V"; \
	if [ "$(DRY_RUN)" = "1" ]; then \
		echo "DRY_RUN git tag $$TAG"; \
	else \
		git tag "$$TAG"; \
	fi; \
	echo "✔ Tagged $$TAG"

# Push commits + tags.
push-release:
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "DRY_RUN git push"; \
		echo "DRY_RUN git push --tags"; \
	else \
		git push; \
		git push --tags; \
	fi

# Create a GitHub release if `gh` is installed. Safe no-op otherwise.
gh-release: version-init
	@V=$$(cat "$(VERSION_FILE)" | tr -d ' \t\n\r'); \
	TAG="$(RELEASE_PREFIX)$$V"; \
	if command -v gh >/dev/null 2>&1; then \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "DRY_RUN gh release create $$TAG --title '$$TAG' --notes 'Release $$TAG'"; \
		else \
			gh release create "$$TAG" --title "$$TAG" --notes "Release $$TAG"; \
		fi; \
	else \
		echo "ℹ️  'gh' not found; skipping GitHub release creation"; \
	fi

# One-shot release target.
# Usage: make release RELEASE=patch|minor|major
release: bump-version commit-release tag-release push-release gh-release
	@echo "✔ Release complete: $(RELEASE_PREFIX)$$(cat "$(VERSION_FILE)")"


# -----------------------------
# Help
# -----------------------------

.PHONY: help
help:
	@echo ""
	@echo "DilexNetworks core-containers Makefile"
	@echo ""
	@echo "Wrappers:"
	@echo "  install           Install docker-backed CLI wrappers into ~/bin"
	@echo "  uninstall         Remove installed wrappers"
	@echo ""
	@echo "Local builds (fast, single-arch):"
	@echo "  build-ci-base     Build ci-base locally"
	@echo "  build-python      Build python locally"
	@echo "  build-hugo        Build hugo locally"
	@echo "  build-aws         Build aws-cli locally"
	@echo "  build-cdk         Build cdk locally"
	@echo "  build-latex       Build latex locally"
	@echo "  build-all         Build ci-base, hugo, aws-cli, cdk"
	@echo ""
	@echo "Local multi-arch builds (buildx, closer to CI):"
	@echo "  buildx-ci-base"
	@echo "  buildx-python"
	@echo "  buildx-hugo"
	@echo "  buildx-aws"
	@echo "  buildx-cdk"
	@echo "  buildx-latex"
	@echo ""
	@echo "Smoke tests:"
	@echo "  smoke-python      Run python + pip sanity checks"
	@echo "  smoke-hugo        Run hugo + sass sanity checks"
	@echo "  smoke-aws         Run aws-cli sanity checks"
	@echo "  smoke-cdk         Run cdk + aws sanity checks"
	@echo ""
	@echo "Published images:"
	@echo "  images-info       Show pinned published image tags"
	@echo "  pull-published    Pull all published images"
	@echo "  pull-python"
	@echo "  pull-hugo"
	@echo "  pull-aws"
	@echo "  pull-cdk"
	@echo "  pull-latex"
	@echo ""
	@echo "Versioning / Release:"
	@echo "  version-init      Create VERSION if missing"
	@echo "  version-show      Show current version"
	@echo "  version-set       Set version explicitly (VERSION=x.y.z)"
	@echo "  bump-version      Bump version (RELEASE=patch|minor|major)"
	@echo "  release           Bump, commit, tag, push, and create GitHub release"
	@echo ""
	@echo "Notes:"
	@echo "  - Local images are tagged as :local and never pushed"
	@echo "  - Published images are multi-arch and pinned"
	@echo ""
