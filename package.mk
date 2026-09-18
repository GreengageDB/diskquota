#!/usr/bin/make -f
# package.mk
#---------------------------------------------------------------------
# Packaging targets with changelog generation
#---------------------------------------------------------------------

SHELL := /bin/bash

.DEFAULT_GOAL := pkg

# Require an explicit version for package-producing goals.
# Other goals may use the default for local convenience.
GP_MAJORVERSION_DEFAULT := 6
PACKAGING_GOALS         := pkg pkg-deb debian/control debian/changelog

ifeq ($(origin GP_MAJORVERSION),undefined)
ifneq (,$(filter $(PACKAGING_GOALS),$(or $(MAKECMDGOALS),$(.DEFAULT_GOAL))))
$(error GP_MAJORVERSION is not set (e.g. GP_MAJORVERSION=6); required to build a package)
else
$(warning GP_MAJORVERSION is not set; defaulting to $(GP_MAJORVERSION_DEFAULT) for \
	'$(or $(MAKECMDGOALS),$(.DEFAULT_GOAL))' - pass GP_MAJORVERSION=<N> explicitly \
	to target a different Greengage major version)
endif
endif
GP_MAJORVERSION ?= $(GP_MAJORVERSION_DEFAULT)

#---------------------------------------------------------------------
# Metadata
#---------------------------------------------------------------------

DATE_RFC       := $(shell date -R)
DISTRO_CODENAME:= $(shell lsb_release -sc)

MAINTAINER     := $(shell grep '^Maintainer:' debian/control.in | sed 's/Maintainer: //')
PACKAGE_SOURCE := $(shell grep '^Source:' debian/control.in | awk '{print $$2}')
PACKAGE_DEBIAN := greengage$(GP_MAJORVERSION)-$(PACKAGE_SOURCE)

# Resolve the package version from an explicit override, git, or .version.
RAW_VERSION := $(or $(DISKQUOTA_PACKAGE_VERSION),\
                     $(shell git describe --tags 2>/dev/null),\
                     $(shell grep -v '$$Format:' .version 2>/dev/null))

ifeq ($(strip $(RAW_VERSION)),)
$(warning No version resolved from DISKQUOTA_PACKAGE_VERSION, git, or .version; \
using 0.0.0+unknown - this package should not be released)
RAW_VERSION := 0.0.0+unknown
endif

# Convert git describe versions to valid Debian versions.
# Matches <version>-<commits>-<hash> and converts it to
# <version>+dev.<commits>.<hash>.
PACKAGE_VERSION := $(shell printf '%s' '$(RAW_VERSION)' | \
                     perl -pe 's/^(.*)-([0-9]+)-(g[0-9a-f]+)$$/\1+dev.\2.\3/')

IS_RELEASE  := $(if $(findstring +dev,$(PACKAGE_VERSION)),no,yes)
BUILD_TYPE  := $(if $(filter yes,$(IS_RELEASE)),Release build,Development build)

DEB_PREREQS := debian/control debian/changelog
DEBUILD_ENV := PG_HOME="$(PG_HOME)" GP_MAJORVERSION="$(GP_MAJORVERSION)"
DEBUILD_CMD := debuild --preserve-env -us -uc -b

PACKAGE_DIR := $(or $(strip $(DEB_PACKAGES)),Package/$(PACKAGE_DEBIAN)_$(PACKAGE_VERSION))

#---------------------------------------------------------------------
# Diagnostics
#---------------------------------------------------------------------

version-info:
	@echo "PACKAGE_VERSION: $(PACKAGE_VERSION)"
	@echo "PACKAGE_DEBIAN:  $(PACKAGE_DEBIAN)"
	@echo "DISTRO_CODENAME: $(DISTRO_CODENAME)"
	@echo "IS_RELEASE:      $(IS_RELEASE)"
	@echo "BUILD_TYPE:      $(BUILD_TYPE)"

#---------------------------------------------------------------------
# Control file / changelog generation
#---------------------------------------------------------------------

# Regenerate files because their contents depend on environment/git state.
debian/control: debian/control.in
	@echo "=== Generating debian/control for GP$(GP_MAJORVERSION) ==="
	sed 's|@GP_MAJORVERSION@|$(GP_MAJORVERSION)|g' $< > $@

changelog: debian/changelog

debian/changelog: debian/control
	@echo "$(PACKAGE_SOURCE) ($(PACKAGE_VERSION)) $(DISTRO_CODENAME); urgency=low" > $@
	@echo "" >> $@
	@echo "  * $(BUILD_TYPE)" >> $@
	@echo "" >> $@
	@echo " -- $(MAINTAINER)  $(DATE_RFC)" >> $@

#---------------------------------------------------------------------
# Packaging
#---------------------------------------------------------------------

pkg: pkg-deb

LOCK_DIR := .debuilder.lock

pkg-deb: $(DEB_PREREQS)
	@mkdir "$(LOCK_DIR)" 2>/dev/null || { \
		echo "ERROR: another Debian package build is already running"; \
		exit 1; \
	}; \
	trap 'rmdir "$(LOCK_DIR)"' EXIT; \
	echo "Building $(PACKAGE_DEBIAN) $(PACKAGE_VERSION)"; \
	$(DEBUILD_ENV) DH_OPTIONS="-p $(PACKAGE_DEBIAN)" $(DEBUILD_CMD); \
	rm -rf $(PACKAGE_DIR); \
	mkdir -p $(PACKAGE_DIR); \
	mv ../$(PACKAGE_DEBIAN){,-dbgsym}_$(PACKAGE_VERSION)_*.*deb $(PACKAGE_DIR)/; \
	mv ../$(PACKAGE_SOURCE)_$(PACKAGE_VERSION)_*.{build,buildinfo,changes} $(PACKAGE_DIR)/

.PHONY: pkg pkg-deb changelog debian/changelog debian/control version-info
