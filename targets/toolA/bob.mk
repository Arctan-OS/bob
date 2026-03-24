DEPS := toolB toolC
VERSION := 123456
URLS := https://a.com/$(VERSION).tar https://a.ca/$(VERSION).tar

.PHONY: build
build:
	@echo "Definitely building"

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

.PHONY: get-source-dir
get-source-dir:
	@echo $(BOB_TARGETS)/toolA
