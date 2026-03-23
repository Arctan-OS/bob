DEPS := toolA
VERSION := 7890
URLS := https://b.com/$(VERSION).tar https://b.ca/$(VERSION).tar

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
