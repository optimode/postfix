.ONESHELL:
ifneq (,)
.error This Makefile requires GNU Make.
endif

ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

# -------------------------------------------------------------------------------------------------
# Version Variables
# -------------------------------------------------------------------------------------------------
# The planned Postfix version (pinned in the Dockerfiles) and the exact Alpine
# base image they are built from. A release is tagged in git with Semantic
# Versioning (e.g. v1.0.0); see the version table in README.md.
#
# Two images are built from this repository:
#
#   ghcr.io/optimode/postfix       Postfix with Cyrus SASL and the
#                                  LMDB/MySQL/SQLite/PCRE lookup tables only -
#                                  a single "postfix start-fg" process
#                                  (Dockerfile)
#   ghcr.io/optimode/postfix-auth  the full authentication stack: saslauthd,
#                                  OpenDKIM and rsyslog under runit
#                                  (Dockerfile.auth)
#
# Tags carry the Postfix version only - the "-alpine" OS suffix is gone,
# because both images are Alpine-based:
#
#   postfix:3.11.7    postfix:3.11    postfix:latest
#   postfix-auth:3.11.7    postfix-auth:3.11    postfix-auth:latest
#
#   make build                                  # build the postfix image
#   make build-auth                             # build the postfix-auth image
#   make build-all                              # build both images
#   make build POSTFIX_VERSION=3.11.8           # build a different Postfix
#   make build ALPINE_VERSION=3.24.5            # build on a newer Alpine
#
POSTFIX_VERSION ?= 3.11.7
ALPINE_VERSION  ?= 3.24.4

# Backwards compatibility: `make build VERSION=x.y.z` sets the Postfix version
ifdef VERSION
POSTFIX_VERSION := $(VERSION)
endif

# Postfix minor version (e.g. 3.11) - used for the moving "3.11" tag
POSTFIX_MINOR = $(shell echo $(POSTFIX_VERSION) | cut -d. -f1,2)

# -------------------------------------------------------------------------------------------------
# Make optional Variables
# -------------------------------------------------------------------------------------------------
ENABLE_CACHE ?= 1

# -------------------------------------------------------------------------------------------------
# Docker required Variables
# -------------------------------------------------------------------------------------------------
DIR        = .
ARCH	   = linux/amd64

# -------------------------------------------------------------------------------------------------
# Docker optional Variables
# -------------------------------------------------------------------------------------------------
CACHE_FLAGS   =
ARGS    =
AUTHORS	= Laszlo Malina <laszlo@malina.hu>
VENDOR	= optimode
URL	= https://github.com/optimode/postfix
SOURCE	= https://github.com/optimode/postfix
REVISION=$(shell git rev-parse --short HEAD)
BUILD_DATE=$(shell date --rfc-3339=s)
BASE_IMAGE = alpine:$(ALPINE_VERSION)
OS_VERSION = Alpine $(ALPINE_VERSION)

# Image names
IMAGE      = ghcr.io/$(VENDOR)/postfix
IMAGE_AUTH = ghcr.io/$(VENDOR)/postfix-auth

# Image tags: immutable version tag + moving minor and latest tags
TAGS_POSTFIX = $(IMAGE):$(POSTFIX_VERSION) \
               $(IMAGE):$(POSTFIX_MINOR) \
               $(IMAGE):latest
TAGS_AUTH    = $(IMAGE_AUTH):$(POSTFIX_VERSION) \
               $(IMAGE_AUTH):$(POSTFIX_MINOR) \
               $(IMAGE_AUTH):latest

# Auto-detect current platform and use it as default to build for
_PLATFORM = $(shell uname -m)
ifeq ($(strip $(_PLATFORM)),x86_64)
	ARCH = linux/amd64
else
	ifeq ($(strip $(_PLATFORM)),arm64)
		ARCH = linux/arm64
	endif
endif

ifeq ($(ENABLE_CACHE),0)
    CACHE_FLAGS+=--no-cache
endif

# -------------------------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------------------------
# build and build-auth share one recipe; the per-image values come from
# target-specific variables (DOCKERFILE, IMAGE_NAME, TAGS).
build: DOCKERFILE = Dockerfile
build: IMAGE_NAME = $(IMAGE)
build: TAGS       = $(TAGS_POSTFIX)

build-auth: DOCKERFILE = Dockerfile.auth
build-auth: IMAGE_NAME = $(IMAGE_AUTH)
build-auth: TAGS       = $(TAGS_AUTH)

.PHONY: build build-auth
build build-auth: ## Build the image. (Usage: make [build|build-auth] [POSTFIX_VERSION=x.y.z] [ALPINE_VERSION=x.y.z])

	@echo "################################################################################"
	@echo "# Building $(IMAGE_NAME):$(POSTFIX_VERSION)"
	@echo "# Postfix $(POSTFIX_VERSION) on $(BASE_IMAGE) (platform: $(ARCH), revision: $(REVISION))"
	@echo "################################################################################"
	docker buildx build \
		$(CACHE_FLAGS) \
		$(ARGS) \
		--network host \
		--platform $(ARCH) \
		--load \
		--build-arg "AUTHORS=$(AUTHORS)" \
		--build-arg "VENDOR=$(VENDOR)" \
		--build-arg "URL=$(URL)" \
		--build-arg "REVISION=$(REVISION)" \
		--build-arg "SOURCE=$(SOURCE)" \
		--build-arg "BUILD_DATE=$(BUILD_DATE)" \
		--build-arg "POSTFIX_VERSION=$(POSTFIX_VERSION)" \
		--build-arg "BASE_IMAGE=$(BASE_IMAGE)" \
		--build-arg "OS_VERSION=$(OS_VERSION)" \
		$(foreach tag,$(TAGS),--tag $(tag)) \
		--file $(DOCKERFILE) $(DIR)
	@echo ""
	@echo "Built tags:"
	@$(foreach tag,$(TAGS),echo "  $(tag)";)
	@echo ""
	@echo "Image metadata:"
	@docker image inspect $(IMAGE_NAME):$(POSTFIX_VERSION) \
		--format '  version={{index .Config.Labels "org.opencontainers.image.version"}} created={{index .Config.Labels "org.opencontainers.image.created"}} revision={{index .Config.Labels "org.opencontainers.image.revision"}} base={{index .Config.Labels "org.opencontainers.image.base.name"}}'

.PHONY: build-all
build-all: build build-auth ## Build both images (postfix and postfix-auth)

push: TAGS = $(TAGS_POSTFIX)
push-auth: TAGS = $(TAGS_AUTH)

.PHONY: push push-auth
push push-auth: ## Push all tags of the given version to the container registry
	@$(foreach tag,$(TAGS),echo "Pushing $(tag)"; docker push $(tag);)

.PHONY: push-all
push-all: push push-auth ## Push both images (postfix and postfix-auth)

.PHONY: help
help:  ## List all available make targets
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo " build                Build the postfix image (Dockerfile)"
	@echo " build-auth           Build the postfix-auth image (Dockerfile.auth)"
	@echo " build-all            Build both images"
	@echo " push                 Push all tags of the postfix image"
	@echo " push-auth            Push all tags of the postfix-auth image"
	@echo " push-all             Push both images"
	@echo ""
	@echo " Optional environment variables:"
	@echo ""
	@echo "  POSTFIX_VERSION=x.y.z Postfix version to pin (default: $(POSTFIX_VERSION))"
	@echo "  ALPINE_VERSION=x.y.z  Alpine base image version (default: $(ALPINE_VERSION))"
	@echo "  VERSION=x.y.z         Alias of POSTFIX_VERSION"
	@echo "  ENABLE_CACHE=0        Disable cache during build (default: 1)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make build-auth push-auth"
	@echo "  make build-all push-all POSTFIX_VERSION=3.11.8 ALPINE_VERSION=3.24.5"
	@echo "  make build push ENABLE_CACHE=0"
