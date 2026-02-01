# Default recipe to display help information
default:
    @just --list

# Format code with rustfmt
format:
    cargo fmt --all

# Check code formatting without modifying files
format-check:
    cargo fmt --all -- --check

# Run clippy linter
lint:
    cargo clippy --all-features -- -D warnings

# Run clippy and automatically fix issues
lint-fix:
    cargo clippy --all-features --fix --allow-dirty --allow-staged

# Run cargo check to verify the project compiles
check: format lint
    cargo check --all-features

# Build the project (library only)
build:
    cargo build

# Build with all features including CLI
build-all:
    cargo build --all-features

# Build release binary
build-release:
    cargo build --release --all-features

# Run all tests
test:
    cargo test --all-features

# Run tests with output
test-verbose:
    cargo test --all-features -- --nocapture

# Clean build artifacts
clean:
    cargo clean

# Generate and open documentation
docs:
    cargo doc --all-features --open

# Publish to crates.io (requires confirmation)
publish:
    cargo publish

# Publish dry-run to check everything before actual publish
publish-dry-run:
    cargo publish --dry-run

# Run CI checks locally (format, lint, test)
ci: format-check lint test

# Install CLI locally
install:
    cargo install --path . --features cli

# Build Docker image for WASM compilation
docker-build:
    docker build -t wasmhub-builder .

# Run Docker container with current directory mounted
docker-run:
    docker run --rm -it -v "$(pwd):/workspace" wasmhub-builder

# Build runtimes inside Docker container
docker-build-runtimes:
    docker run --rm -v "$(pwd):/workspace" wasmhub-builder ./scripts/build-all.sh
