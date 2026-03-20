ARC_REPO := https://github.com/managarm/mlibc
ARC_VERSION := af271dbcf0a4ea52e848c024a03252ed449d77f8
              #25439798f12e44f31c6a059bb2507735529acdd2
              #fae50a5e9ac246e3fc03bcc26090db6ae43b5b3f
ARC_NAME := mlibc-$(ARC_VERSION)
ARC_TAR := $(ARC_NAME).tar.gz
ARC_MIRROR := $(ARC_REPO)/archive/$(ARC_VERSION).tar.gz
ARC_DEPS :=

MESON_FLAGS := --reconfigure --cross-file $(ARC_BUILD_SUPPORT)/meson.cross --prefix=$(ARC_HOST_PREFIX) \
		--buildtype=debugoptimized -Ddefault_library=both \
		build

NINJA_FLAGS := -C build

.PHONY: build
build:
	mkdir -p $(ARC_SOURCE_DIR)/build

	cd $(ARC_SOURCE_DIR) && meson subprojects download
	cd $(ARC_SOURCE_DIR) && $(ARC_SET_COMPILER_ENV_FLAGS) meson setup $(MESON_FLAGS) -Dheaders_only=true
	meson install -C $(ARC_SOURCE_DIR)/build

.PHONY: clean
clean:
	@echo "Definitely cleaning"

.PHONY: get-deps
get-deps:
	@echo $(ARC_DEPS)

.PHONY: get-version
get-version:
	@echo $(ARC_VERSION)

.PHONY: get-urls
get-urls:
	@echo $(ARC_MIRROR)
