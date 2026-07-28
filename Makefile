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

# Shared image versions and registry settings
ALPINE_VERSION := 3.24.1
BASE_REV := 1
HUGO_VERSION := 0.161.1
SASS_VERSION := 1.97.1
AWSCLI_VERSION := 2.34.63
WORK_VERSION := 0.3.2

DOCKERHUB_NS := wyllie
GHCR_NS := ghcr.io/dilexnetworks

# Image tags (single source of truth)
CI_BASE_IMAGE := $(DOCKERHUB_NS)/ci-base:alpine$(ALPINE_VERSION)-$(BASE_REV)
HUGO_IMAGE := $(DOCKERHUB_NS)/hugo:hugo$(HUGO_VERSION)-sass$(SASS_VERSION)-alpine$(ALPINE_VERSION)-$(BASE_REV)
AWS_IMAGE := $(DOCKERHUB_NS)/aws-cli:awscli$(AWSCLI_VERSION)-alpine$(ALPINE_VERSION)-$(BASE_REV)
CDK_IMAGE := $(DOCKERHUB_NS)/cdk:awscli$(AWSCLI_VERSION)-alpine$(ALPINE_VERSION)-$(BASE_REV)
PYTHON_IMAGE := $(DOCKERHUB_NS)/python:python3-alpine$(ALPINE_VERSION)-$(BASE_REV)
WORK_IMAGE := $(DOCKERHUB_NS)/work:work$(WORK_VERSION)-python3-alpine$(ALPINE_VERSION)-$(BASE_REV)
LATEX_IMAGE := $(DOCKERHUB_NS)/latex:alpine$(ALPINE_VERSION)-texlive-$(BASE_REV)

# Local test tags (for fast iteration without waiting on GitHub Actions)
CI_BASE_LOCAL := wyllie/ci-base:local
PYTHON_LOCAL := wyllie/python:local
WORK_LOCAL := wyllie/work:local
HUGO_LOCAL := wyllie/hugo:local
AWS_LOCAL := wyllie/aws-cli:local
CDK_LOCAL := wyllie/cdk:local
LATEX_LOCAL := wyllie/latex:local

# Docker build platforms
LOCAL_PLATFORM ?= linux/arm64
PLATFORMS ?= linux/amd64,linux/arm64

.PHONY: install uninstall check-bin \
	build-ci-base build-python build-work build-hugo build-aws build-cdk build-latex \
	build-all buildx-ci-base buildx-python buildx-work buildx-hugo buildx-aws buildx-cdk buildx-latex \
	publish-ci-base publish-python publish-work publish-hugo publish-aws publish-cdk publish-latex publish-all \
	smoke-python smoke-work smoke-hugo smoke-aws smoke-cdk \
	pull-published pull-ci-base pull-python pull-work pull-hugo pull-aws pull-cdk pull-latex \
	images-info github-actions-env \
	version-init version-show version-set bump-version release commit-release tag-release push-release gh-release help

check-bin:
	@mkdir -p $(BIN_DIR)

install: check-bin
	@echo "Installing docker-backed CLI wrappers into $(BIN_DIR)"
	@sed "s|@@HUGO_IMAGE@@|$(HUGO_IMAGE)|g" $(WRAPPER_DIR)/hugo > $(BIN_DIR)/hugo
	@sed "s|@@AWS_IMAGE@@|$(AWS_IMAGE)|g" $(WRAPPER_DIR)/aws > $(BIN_DIR)/aws
	@sed "s|@@CDK_IMAGE@@|$(CDK_IMAGE)|g" $(WRAPPER_DIR)/cdk > $(BIN_DIR)/cdk
	@sed "s|@@WORK_IMAGE@@|$(WORK_IMAGE)|g" $(WRAPPER_DIR)/work > $(BIN_DIR)/work
	@chmod +x $(BIN_DIR)/hugo $(BIN_DIR)/aws $(BIN_DIR)/cdk $(BIN_DIR)/work
	@echo "✔ Installed: hugo, aws, cdk, work"

uninstall:
	@echo "Removing docker-backed CLI wrappers from $(BIN_DIR)"
	@rm -f $(BIN_DIR)/hugo $(BIN_DIR)/aws $(BIN_DIR)/cdk $(BIN_DIR)/work
	@echo "✔ Removed"


# -----------------------------
# Local build targets (single-arch, fast)
# -----------------------------

build-ci-base:
	docker build \
		--build-arg BASE_IMAGE=alpine:$(ALPINE_VERSION) \
		-t $(CI_BASE_LOCAL) \
		images/ci-base

build-python: build-ci-base
	docker build \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		-t $(PYTHON_LOCAL) \
		images/python

build-work: build-python
	docker build \
		--build-arg BASE_IMAGE=$(PYTHON_LOCAL) \
		--build-arg WORK_VERSION=$(WORK_VERSION) \
		-t $(WORK_LOCAL) \
		images/work

build-hugo: build-ci-base
	docker build \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--build-arg DART_SASS_VERSION=$(SASS_VERSION) \
		-t $(HUGO_LOCAL) \
		images/hugo

build-aws: build-ci-base
	docker build \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		-t $(AWS_LOCAL) \
		images/aws-cli

build-cdk: build-aws
	docker build \
		--build-arg BASE_IMAGE=$(AWS_LOCAL) \
		-t $(CDK_LOCAL) \
		images/cdk

build-latex: build-ci-base
	docker build \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		-t $(LATEX_LOCAL) \
		images/latex

build-all: build-ci-base build-python build-work build-hugo build-aws build-cdk


# -----------------------------
# Local buildx targets (single-platform, loadable)
# -----------------------------

buildx-ci-base:
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=alpine:$(ALPINE_VERSION) \
		-t $(CI_BASE_LOCAL) \
		--load \
		images/ci-base

buildx-python: buildx-ci-base
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		-t $(PYTHON_LOCAL) \
		--load \
		images/python

buildx-work: buildx-python
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=$(PYTHON_LOCAL) \
		--build-arg WORK_VERSION=$(WORK_VERSION) \
		-t $(WORK_LOCAL) \
		--load \
		images/work

buildx-hugo: buildx-ci-base
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--build-arg DART_SASS_VERSION=$(SASS_VERSION) \
		-t $(HUGO_LOCAL) \
		--load \
		images/hugo

buildx-aws: buildx-ci-base
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		-t $(AWS_LOCAL) \
		--load \
		images/aws-cli

buildx-cdk: buildx-aws
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=$(AWS_LOCAL) \
		-t $(CDK_LOCAL) \
		--load \
		images/cdk

buildx-latex: buildx-ci-base
	docker buildx build \
		--platform $(LOCAL_PLATFORM) \
		--build-arg BASE_IMAGE=$(CI_BASE_LOCAL) \
		-t $(LATEX_LOCAL) \
		--load \
		images/latex

buildx-all: buildx-ci-base buildx-python buildx-work buildx-hugo buildx-aws buildx-cdk


# -----------------------------
# Multi-platform publish targets
# -----------------------------

publish-ci-base:
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=alpine:$(ALPINE_VERSION) \
		-t $(CI_BASE_IMAGE) \
		--push \
		images/ci-base

publish-python: publish-ci-base
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(CI_BASE_IMAGE) \
		-t $(PYTHON_IMAGE) \
		--push \
		images/python

publish-work: publish-python
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(PYTHON_IMAGE) \
		--build-arg WORK_VERSION=$(WORK_VERSION) \
		-t $(WORK_IMAGE) \
		--push \
		images/work

publish-hugo: publish-ci-base
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(CI_BASE_IMAGE) \
		--build-arg HUGO_VERSION=$(HUGO_VERSION) \
		--build-arg DART_SASS_VERSION=$(SASS_VERSION) \
		-t $(HUGO_IMAGE) \
		--push \
		images/hugo

publish-aws: publish-ci-base
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(CI_BASE_IMAGE) \
		-t $(AWS_IMAGE) \
		--push \
		images/aws-cli

publish-cdk: publish-aws
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(AWS_IMAGE) \
		-t $(CDK_IMAGE) \
		--push \
		images/cdk

publish-latex: publish-ci-base
	docker buildx build \
		--platform $(PLATFORMS) \
		--build-arg BASE_IMAGE=$(CI_BASE_IMAGE) \
		-t $(LATEX_IMAGE) \
		--push \
		images/latex

publish-all: publish-ci-base publish-python publish-work publish-hugo publish-aws publish-cdk publish-latex


# -----------------------------
# Smoke tests (run local tags)
# -----------------------------

smoke-python: build-python
	docker run --rm $(PYTHON_LOCAL) uname -a
	docker run --rm $(PYTHON_LOCAL) python --version
	docker run --rm $(PYTHON_LOCAL) pip --version

smoke-work: build-work
	docker run --rm $(WORK_LOCAL) --help

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
	@echo "  alpine    : $(ALPINE_VERSION)"
	@echo "  aws-cli   : $(AWSCLI_VERSION)"
	@echo "  ci-base   : $(CI_BASE_IMAGE)"
	@echo "  python    : $(PYTHON_IMAGE)"
	@echo "  work      : $(WORK_IMAGE)"
	@echo "  hugo      : $(HUGO_IMAGE)"
	@echo "  aws-cli   : $(AWS_IMAGE)"
	@echo "  cdk       : $(CDK_IMAGE)"

# Export the Makefile's image metadata in GitHub Actions environment-file format.
# Usage from a workflow step:
#     make -s github-actions-env >> "$$GITHUB_ENV"
github-actions-env:
	@echo "ALPINE_VERSION=$(ALPINE_VERSION)"
	@echo "BASE_REV=$(BASE_REV)"
	@echo "HUGO_VERSION=$(HUGO_VERSION)"
	@echo "SASS_VERSION=$(SASS_VERSION)"
	@echo "AWSCLI_VERSION=$(AWSCLI_VERSION)"
	@echo "WORK_VERSION=$(WORK_VERSION)"
	@echo "DOCKERHUB_NS=$(DOCKERHUB_NS)"
	@echo "GHCR_NS=$(GHCR_NS)"
	@echo "CI_BASE_IMAGE=$(CI_BASE_IMAGE)"
	@echo "PYTHON_IMAGE=$(PYTHON_IMAGE)"
	@echo "WORK_IMAGE=$(WORK_IMAGE)"
	@echo "HUGO_IMAGE=$(HUGO_IMAGE)"
	@echo "AWS_IMAGE=$(AWS_IMAGE)"
	@echo "CDK_IMAGE=$(CDK_IMAGE)"
	@echo "LATEX_IMAGE=$(LATEX_IMAGE)"

pull-ci-base:
	docker pull $(CI_BASE_IMAGE)

pull-python:
	docker pull $(PYTHON_IMAGE)

pull-work:
	docker pull $(WORK_IMAGE)

pull-hugo:
	docker pull $(HUGO_IMAGE)

pull-aws:
	docker pull $(AWS_IMAGE)

pull-cdk:
	docker pull $(CDK_IMAGE)

pull-latex:
	docker pull $(LATEX_IMAGE)

pull-published: pull-ci-base pull-python pull-work pull-hugo pull-aws pull-cdk pull-latex
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
	@echo "  build-work        Build work locally"
	@echo "  build-hugo        Build hugo locally"
	@echo "  build-aws         Build aws-cli locally"
	@echo "  build-cdk         Build cdk locally"
	@echo "  build-latex       Build latex locally"
	@echo "  build-all         Build all local images"
	@echo ""
	@echo "Local buildx builds (single-platform, loadable):"
	@echo "  buildx-ci-base"
	@echo "  buildx-python"
	@echo "  buildx-work"
	@echo "  buildx-hugo"
	@echo "  buildx-aws"
	@echo "  buildx-cdk"
	@echo "  buildx-latex"
	@echo "  buildx-all"
	@echo ""
	@echo "Multi-platform publish targets:"
	@echo "  publish-ci-base"
	@echo "  publish-python"
	@echo "  publish-work"
	@echo "  publish-hugo"
	@echo "  publish-aws"
	@echo "  publish-cdk"
	@echo "  publish-latex"
	@echo "  publish-all"
	@echo ""
	@echo "Smoke tests:"
	@echo "  smoke-python      Run python + pip sanity checks"
	@echo "  smoke-work        Run work CLI sanity check"
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
	@echo "  pull-work"
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
	@echo "  - LOCAL_PLATFORM controls loadable buildx builds"
	@echo "  - PLATFORMS controls multi-platform publish builds"
	@echo "  - Published images are multi-arch and pinned"
	@echo ""
