.ONESHELL:
ifneq (,)
.error This Makefile requires GNU Make.
endif

ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

# -------------------------------------------------------------------------------------------------
# Make required Variables
# -------------------------------------------------------------------------------------------------
VERSION =

# -------------------------------------------------------------------------------------------------
# Make optional Variables
# -------------------------------------------------------------------------------------------------
ENABLE_CACHE ?= 1
USE_BUILDKIT ?= 1

# -------------------------------------------------------------------------------------------------
# Docker required Variables
# -------------------------------------------------------------------------------------------------
DIR        = .
FILE       = Dockerfile
ARCH	   = linux/amd64

# -------------------------------------------------------------------------------------------------
# Docker optional Variables
# -------------------------------------------------------------------------------------------------
CACHE_FLAGS   =
BUILDKIT_FLAGS =
ARGS    =
AUTHORS	= Laszlo Malina <laszlo@malina.hu>
VENDOR	= optimode
URL	= https://github.com/optimode/docker-postfix
SOURCE	= https://github.com/optimode/docker-postfix
REVISION=$(shell git rev-parse --short HEAD)
BUILD_DATE=$(shell date --rfc-3339=s)
DATE=$(shell date +'%Y%m%d%H%M%S')
IMAGE = $(VENDOR)/docker-postfix

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

BUILDKIT_FLAGS=
ifeq ($(USE_BUILDKIT),1)
    BUILDKIT_FLAGS+=--progress=plain
endif

# -------------------------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------------------------
.PHONY: build
build: ## Build for a specific version. (Usage: make build VERSION=8.4-cli)

	TAG="latest"
	DIR="."

	@echo "################################################################################"
	@echo "# Building $(IMAGE):$$TAG (platform: $(ARCH))"
	@echo "################################################################################"
	DOCKER_BUILDKIT=$(USE_BUILDKIT) docker build \
		$(CACHE_FLAGS) \
		$(BUILDKIT_FLAGS) \
		$(ARGS) \
		--network host \
		--platform $(ARCH) \
		--build-arg "AUTHORS=$(AUTHORS)" \
		--build-arg "VENDOR=$(VENDOR)" \
		--build-arg "URL=$(URL)" \
		--build-arg "REVISION=$(REVISION)" \
		--build-arg "SOURCE=$(SOURCE)" \
		--build-arg "BUILD_DATE=$(BUILD_DATE)" \
		--tag $(IMAGE):$$TAG \
		--tag $(IMAGE):$$TAG-$(DATE) \
		--file $$DIR/$(FILE) $$DIR

.PHONY: push
push:  ## Push the given version to the container registry
	docker push $(IMAGE_NAME)

.PHONY: help
help:  ## List all available make targets
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo " build                Build the Docker image"
	@echo ""
	@echo " Optional environment variables:"
	@echo ""
	@echo "  ENABLE_CACHE=0        Disable cache during build (default: 1)"
	@echo "  USE_BUILDKIT=0        Disable buildkit during build (default: 1)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make build ENABLE_CACHE=0 USE_BUILDKIT=0"
