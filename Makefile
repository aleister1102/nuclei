# Go parameters
GOCMD := go
GOBUILD := $(GOCMD) build
GOBUILD_OUTPUT := 
GOBUILD_PACKAGES := 
GOBUILD_ADDITIONAL_ARGS := 
GOMOD := $(GOCMD) mod
GOTEST := $(GOCMD) test
GOFLAGS := -v
# This should be disabled if the binary uses pprof
LDFLAGS := -s -w

ifneq ($(shell go env GOOS),darwin)
	LDFLAGS += -extldflags "-static"
endif
    
.PHONY: all build build-stats clean devtools-all devtools-bindgen devtools-scrapefuncs
.PHONY: devtools-tsgen docs docgen dsl-docs functional fuzzplayground go-build lint lint-strict syntax-docs
.PHONY: integration jsupdate-all jsupdate-bindgen jsupdate-tsgen memogen scan-charts test test-with-lint
.PHONY: tidy ts verify download vet template-validate

all: build

clean:
	rm -f '${GOBUILD_OUTPUT}' 2>/dev/null

go-build: clean
go-build:
	CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' $(GOBUILD_ADDITIONAL_ARGS) \
		 -o '${GOBUILD_OUTPUT}' $(GOBUILD_PACKAGES)

build: GOFLAGS = -v -pgo=auto
build: GOBUILD_OUTPUT = ./bin/nuclei
build: GOBUILD_PACKAGES = cmd/nuclei/main.go
build: go-build

build-test: GOFLAGS = -v -pgo=auto
build-test: GOBUILD_OUTPUT = ./bin/nuclei.test
build-test: GOBUILD_PACKAGES = ./cmd/nuclei/
build-test: clean
build-test:
	CGO_ENABLED=0 $(GOCMD) test -c -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' $(GOBUILD_ADDITIONAL_ARGS) \
		 -o '${GOBUILD_OUTPUT}' ${GOBUILD_PACKAGES}

build-stats: GOBUILD_OUTPUT = ./bin/nuclei-stats
build-stats: GOBUILD_PACKAGES = cmd/nuclei/main.go
build-stats: GOBUILD_ADDITIONAL_ARGS = -tags=stats
build-stats: go-build

scan-charts: GOBUILD_OUTPUT = ./bin/scan-charts
scan-charts: GOBUILD_PACKAGES = cmd/scan-charts/main.go
scan-charts: go-build

template-signer: GOBUILD_OUTPUT = ./bin/template-signer
template-signer: GOBUILD_PACKAGES = cmd/tools/signer/main.go
template-signer: go-build

docgen: GOBUILD_OUTPUT = ./bin/docgen
docgen: GOBUILD_PACKAGES = cmd/docgen/docgen.go
docgen: bin = dstdocgen
docgen:
	@if ! which $(bin) >/dev/null; then \
		echo "Command $(bin) not found! Installing..."; \
		go install -v github.com/projectdiscovery/yamldoc-go/cmd/docgen/$(bin)@latest; \
	fi
	# TODO: FIX THIS PANIC
	$(GOCMD) generate pkg/templates/templates.go
	$(GOBUILD) -o "${GOBUILD_OUTPUT}" $(GOBUILD_PACKAGES)

docs: docgen
docs:
	./bin/docgen docs.md nuclei-jsonschema.json

syntax-docs: docgen
syntax-docs:
	./bin/docgen SYNTAX-REFERENCE.md nuclei-jsonschema.json

test: GOFLAGS = -race -v -timeout 30m -count 1
test:
	$(GOTEST) $(GOFLAGS) ./...

integration:
	cd integration_tests; bash run.sh

functional:
	cd cmd/functional-test; bash run.sh

tidy:
	$(GOMOD) tidy

download:
	$(GOMOD) download

verify: download
	$(GOMOD) verify

vet: verify
	$(GOCMD) vet ./...

devtools-bindgen: GOBUILD_OUTPUT = ./bin/bindgen
devtools-bindgen: GOBUILD_PACKAGES = pkg/js/devtools/bindgen/cmd/bindgen/main.go
devtools-bindgen: go-build

devtools-tsgen: GOBUILD_OUTPUT = ./bin/tsgen
devtools-tsgen: GOBUILD_PACKAGES = pkg/js/devtools/tsgen/cmd/tsgen/main.go
devtools-tsgen: go-build

devtools-scrapefuncs: GOBUILD_OUTPUT = ./bin/scrapefuncs
devtools-scrapefuncs: GOBUILD_PACKAGES = pkg/js/devtools/scrapefuncs/main.go
devtools-scrapefuncs: go-build

devtools-all: devtools-bindgen devtools-tsgen devtools-scrapefuncs

jsupdate-bindgen: GOBUILD_OUTPUT = ./bin/bindgen
jsupdate-bindgen: GOBUILD_PACKAGES = pkg/js/devtools/bindgen/cmd/bindgen/main.go
jsupdate-bindgen: go-build
jsupdate-bindgen:
	./$(GOBUILD_OUTPUT) -dir pkg/js/libs -out pkg/js/generated

jsupdate-tsgen: GOBUILD_OUTPUT = ./bin/tsgen
jsupdate-tsgen: GOBUILD_PACKAGES = pkg/js/devtools/tsgen/cmd/tsgen/main.go
jsupdate-tsgen: go-build
jsupdate-tsgen:
	./$(GOBUILD_OUTPUT) -dir pkg/js/libs -out pkg/js/generated/ts

jsupdate-all: jsupdate-bindgen jsupdate-tsgen

ts: jsupdate-tsgen

fuzzplayground: GOBUILD_OUTPUT = ./bin/fuzzplayground
fuzzplayground: GOBUILD_PACKAGES = cmd/tools/fuzzplayground/main.go
fuzzplayground: LDFLAGS = -s -w
fuzzplayground: go-build

memogen: GOBUILD_OUTPUT = ./bin/memogen
memogen: GOBUILD_PACKAGES = cmd/memogen/memogen.go
memogen: go-build
memogen:
	./$(GOBUILD_OUTPUT) -src pkg/js/libs -tpl cmd/memogen/function.tpl

dsl-docs: GOBUILD_OUTPUT = ./bin/scrapefuncs
dsl-docs: GOBUILD_PACKAGES = pkg/js/devtools/scrapefuncs/main.go
dsl-docs:
	./$(GOBUILD_OUTPUT) -out dsl.md

template-validate: build
template-validate:
	./bin/nuclei -ut
	./bin/nuclei -validate \
		-et http/technologies \
		-t dns \
		-t ssl \
		-t network \
		-t http/exposures \
		-ept code
	./bin/nuclei -validate \
		-w workflows \
		-et http/technologies \
		-ept code

# Release targets
BINARY_NAME=nuclei
BUILD_DIR=dist
COMMIT=$(shell git rev-parse --short HEAD)
DATE=$(shell date +%Y-%m-%d)
CURRENT_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)
VERSION_PARTS := $(subst ., ,$(subst v,,$(CURRENT_TAG)))
MAJOR := $(word 1,$(VERSION_PARTS))
MINOR := $(word 2,$(VERSION_PARTS))
PATCH := $(word 3,$(VERSION_PARTS))
NEXT_PATCH := v$(MAJOR).$(MINOR).$(shell echo $(($(PATCH)+1)))
NEXT_MINOR := v$(MAJOR).$(shell echo $(($(MINOR)+1))).0
NEXT_MAJOR := v$(shell echo $(($(MAJOR)+1))).0.0

.PHONY: release bump-patch bump-minor bump-major

release: ## Release new version (usage: make release TAG=v1.0.0)
	@if [ -z "$(TAG)" ]; then echo "Usage: make release TAG=v1.0.0"; exit 1; fi
	@echo "Releasing $(TAG)..."
	@rm -rf $(BUILD_DIR) && mkdir -p $(BUILD_DIR)
	@echo "Building binaries..."
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 cmd/nuclei/main.go
	@GOOS=linux GOARCH=arm64 CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 cmd/nuclei/main.go
	@GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 cmd/nuclei/main.go
	@GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 cmd/nuclei/main.go
	@GOOS=windows GOARCH=amd64 CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe cmd/nuclei/main.go
	@GOOS=windows GOARCH=arm64 CGO_ENABLED=0 $(GOBUILD) -trimpath $(GOFLAGS) -ldflags '${LDFLAGS}' -o $(BUILD_DIR)/$(BINARY_NAME)-windows-arm64.exe cmd/nuclei/main.go
	@cd $(BUILD_DIR) && shasum -a 256 * > checksums.txt
	@echo "Creating GitHub release..."
	@git tag -d $(TAG) 2>/dev/null || true
	@git tag -a $(TAG) -m "Release $(TAG)"
	@git push origin $(TAG) --force
	@gh release delete $(TAG) -y -R aleister1102/nuclei 2>/dev/null || true
	@gh release create $(TAG) $(BUILD_DIR)/$(BINARY_NAME)-* $(BUILD_DIR)/checksums.txt --title "$(BINARY_NAME) $(TAG)" --generate-notes -R aleister1102/nuclei
	@rm -rf $(BUILD_DIR)
	@echo "Done: $(TAG)"

bump-patch: ## Release next patch version
	@$(MAKE) release TAG=$(NEXT_PATCH)

bump-minor: ## Release next minor version
	@$(MAKE) release TAG=$(NEXT_MINOR)

bump-major: ## Release next major version
	@$(MAKE) release TAG=$(NEXT_MAJOR)