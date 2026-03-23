VERSION := 2.72
NAME := autoconf-$(VERSION)
URLS := https://ftp.gnu.org/gnu/autoconf/$(NAME).tar.gz
DEPS :=

.PHONY: build
build:
	@echo "Definitely building SOURCE_DIR=$(SOURCE_DIR)"

.PHONY: clean
clean:
	@echo "Definitely cleaning"

.PHONY: prepare-rebuild
prepare-rebuild:
	@echo "Definitely preparing rebuild"

.PHONY: get-deps
get-deps:
	@echo $(DEPS)

.PHONY: get-version
get-version:
	@echo $(VERSION)

.PHONY: get-urls
get-urls:
	@echo $(URLS)

