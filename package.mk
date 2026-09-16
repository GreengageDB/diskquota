#!/usr/bin/make -f
# package.mk
#---------------------------------------------------------------------
# Packaging targets with changelog options
#---------------------------------------------------------------------

SHELL := /bin/bash

# Metadata vars
DATE_RFC	   := $(shell date -R)
ARTIFACTS_DIR  := $(CURDIR)/./Package
MAINTAINER     := $(shell grep '^Maintainer:' debian/control.in | sed 's/Maintainer: //')
PACKAGE_SOURCE := $(shell grep '^Source:' debian/control.in | awk '{print $$2}')
PACKAGE_DEBIAN := greengage$(GP_MAJORVERSION)-$(PACKAGE_SOURCE)

VERSION :
	@cat $@

version: VERSION

version-vars: version
	$(eval FULL_VERSION    := $(shell perl -pe 's, ,-,g' ./VERSION))
	$(eval PACKAGE_VERSION := $(shell perl -pe 's, .*,,g; s/-SNAPSHOT/~snapshot/' ./VERSION))
	$(eval DISTRO_CODENAME := $(shell lsb_release -sc))
	$(eval IS_RELEASE      := $(if $(findstring ~snapshot,$(PACKAGE_VERSION)),no,yes))
	$(eval BUILD_TYPE      := $(if $(filter yes,$(IS_RELEASE)),Release build,Development build))

version-info : version-vars
	@echo "PACKAGE_VERSION: $(PACKAGE_VERSION)"
	@echo "FULL_VERSION: $(FULL_VERSION)"
	@echo "DISTRO_CODENAME: $(DISTRO_CODENAME)"
	@echo "IS_RELEASE: $(IS_RELEASE)"
	@echo "BUILD_TYPE: $(BUILD_TYPE)"

# Generate control file
debian/control: debian/control.in
	@echo "=== Generating debian/control for GP$(GP_MAJORVERSION) ==="
	sed 's|@GP_MAJORVERSION@|$(GP_MAJORVERSION)|g' $< > $@

# Generate package control files
changelog : debian/changelog
debian/changelog: version-vars debian/control
	@echo "$(PACKAGE_SOURCE) ($(PACKAGE_VERSION)) $(DISTRO_CODENAME); urgency=low" > $@
	@echo "" >> $@
	@echo "  * $(BUILD_TYPE)" >> $@
	@echo "" >> $@
	@echo " -- $(MAINTAINER)  $(DATE_RFC)" >> $@

DEB_PREREQS := debian/changelog debian/control
DEBUILD_ENV := PG_HOME="$(PG_HOME)" GP_MAJORVERSION="$(GP_MAJORVERSION)"
DEBUILD_CMD := debuild --preserve-env -us -uc -b

# Default packaging target
pkg : pkg-deb

pkg-deb: $(DEB_PREREQS)
	@echo "Building diskquota package"
	@$(DEBUILD_ENV) DH_OPTIONS="-p $(PACKAGE_DEBIAN)" $(DEBUILD_CMD)
	@mkdir -p $(ARTIFACTS_DIR)
	@find $(CURDIR)/../ -maxdepth 1 -type f \( -name "*.deb" \
	                                        -o -name "*.ddeb" \
	                                        -o -name "*.build" \
	                                        -o -name "*.buildinfo" \
	                                        -o -name "*.changes" \) \
	                                        -exec mv -f {} $(ARTIFACTS_DIR)/ \;

.PHONY: pkg pkg-deb changelog debian/changelog debian/control version-vars version-info version VERSION
