.PHONY: all build build-static build-alpine build-astra build-all test test-go test-bash deps clean install help

# Variables
BINARY_NAME=jwt-parser
GO=go
GOFLAGS=-ldflags="-s -w"

# Default target
all: build

# Build for current platform
build:
	@echo "Building $(BINARY_NAME) for current platform..."
	$(GO) build -o $(BINARY_NAME) $(GOFLAGS) jwt-parser.go
	@echo "Build complete: ./$(BINARY_NAME)"

# Build static binary (no CGO dependencies)
build-static:
	@echo "Building static $(BINARY_NAME)..."
	CGO_ENABLED=0 $(GO) build -o $(BINARY_NAME)-static $(GOFLAGS) jwt-parser.go
	@echo "Static build complete: ./$(BINARY_NAME)-static"
	@echo "Size: $$(du -h $(BINARY_NAME)-static | cut -f1)"

# Build for Alpine Linux (minimal images)
build-alpine:
	@echo "Building $(BINARY_NAME) for Alpine Linux..."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build -o $(BINARY_NAME)-alpine $(GOFLAGS) jwt-parser.go
	@echo "Alpine build complete: ./$(BINARY_NAME)-alpine"
	@echo "Size: $$(du -h $(BINARY_NAME)-alpine | cut -f1)"

# Build for Astra Linux (x86_64)
build-astra:
	@echo "Building $(BINARY_NAME) for Astra Linux..."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GO) build -o $(BINARY_NAME)-astra $(GOFLAGS) jwt-parser.go
	@echo "Astra build complete: ./$(BINARY_NAME)-astra"
	@echo "Size: $$(du -h $(BINARY_NAME)-astra | cut -f1)"

# Build for all target platforms
build-all: build build-static build-alpine build-astra
	@echo "All builds complete"
	@ls -lh $(BINARY_NAME)*

# Run all tests (Bash + Go)
test:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Running JWT Parser Test Suite"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "1. Bash Unit Tests..."
	@bash tests/unit/test_bash_parser.sh || true
	@echo ""
	@echo "2. Security Tests..."
	@bash tests/security/test_security.sh || true
	@echo ""
	@echo "3. Compatibility Tests..."
	@bash tests/compatibility/test_compatibility.sh || true
	@echo ""
	@echo "4. Integration Tests..."
	@bash tests/integration/test_integration.sh || true
	@echo ""
	@echo "5. Go Unit Tests..."
	@$(GO) test -v
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Test Summary: See tests/TEST_SUMMARY.txt for full report"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run only Go tests
test-go:
	@echo "Running Go tests..."
	$(GO) test -v ./...

# Run only Bash tests
test-bash:
	@echo "Running Bash tests..."
	@bash tests/unit/test_bash_parser.sh
	@bash tests/security/test_security.sh
	@bash tests/compatibility/test_compatibility.sh
	@bash tests/integration/test_integration.sh

# Install dependencies
deps:
	@echo "Installing dependencies..."
	$(GO) mod download
	$(GO) mod verify

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BINARY_NAME) $(BINARY_NAME)-* jwt-parser
	$(GO) clean

# Install to /usr/local/bin
install: build-static
	@echo "Installing $(BINARY_NAME) to /usr/local/bin..."
	sudo cp $(BINARY_NAME)-static /usr/local/bin/$(BINARY_NAME)
	sudo chmod +x /usr/local/bin/$(BINARY_NAME)
	@echo "Installation complete"

# Show help
help:
	@echo "JWT Parser - Makefile targets:"
	@echo ""
	@echo "  make build         - Build for current platform"
	@echo "  make build-static  - Build static binary (no dependencies)"
	@echo "  make build-alpine  - Build for Alpine Linux"
	@echo "  make build-astra   - Build for Astra Linux"
	@echo "  make build-all     - Build for all platforms"
	@echo "  make test          - Run tests"
	@echo "  make deps          - Install dependencies"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make install       - Install to /usr/local/bin"
	@echo "  make help          - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make build && ./jwt-parser --help"
	@echo "  make build-alpine  # for Docker Alpine images"
	@echo "  make install       # system-wide installation"
