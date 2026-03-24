VERSION := 123456
STAGING := disabled
.PHONY: build
build:
	@echo "Definitely building"

.PHONY: clean
clean:
	@echo "Definitely cleaning"

.PHONY: prepare-rebuild
prepare-rebuild:
	@echo "Definitely preparing rebuild"

.PHONY: get-version
get-version:
	@echo $(VERSION)

.PHONY: get-source-dir
get-source-dir:
	@echo $(BOB_TARGETS)/toolA

.PHONY: get-staging
get-staging:
	@echo $(STAGING)
