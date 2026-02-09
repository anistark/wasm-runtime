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

# Publish release (extracts version from Cargo.toml)
publish:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    echo "Detected version: ${VERSION}"
    just release "${VERSION}"

# Publish to crates.io only (no git tag or GitHub release)
publish-crates:
    cargo publish

# Publish dry-run to check everything before actual publish
publish-check:
    cargo publish --dry-run

# Publish to GitHub only (no crates.io), extracts version from Cargo.toml
publish-github:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    echo "Detected version: ${VERSION}"
    just release-github "${VERSION}"

# Create a new release (tag + GitHub release + crates.io)
# Usage: just release 0.2.0
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION="{{version}}"
    TAG="v${VERSION}"

    echo "Preparing release ${TAG}..."

    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Error: Working directory has uncommitted changes"
        exit 1
    fi

    # Check we're on main branch
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${BRANCH}" != "main" ]]; then
        echo "Warning: Not on main branch (currently on ${BRANCH})"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Verify version matches Cargo.toml
    CARGO_VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [[ "${CARGO_VERSION}" != "${VERSION}" ]]; then
        echo "Error: Version mismatch - Cargo.toml has ${CARGO_VERSION}, releasing ${VERSION}"
        echo "Update Cargo.toml version first"
        exit 1
    fi

    # Run CI checks
    echo "Running CI checks..."
    just ci

    # Dry-run crates.io publish
    echo "Checking crates.io publish..."
    cargo publish --dry-run

    echo ""
    echo "Ready to release ${TAG}"
    echo "This will:"
    echo "  1. Create and push git tag ${TAG}"
    echo "  2. Create GitHub release (triggers WASM builds)"
    echo "  3. Publish to crates.io"
    echo ""
    read -p "Proceed? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi

    # Create and push tag
    echo "Creating tag ${TAG}..."
    git tag -a "${TAG}" -m "Release ${TAG}"
    git push origin "${TAG}"

    # Create GitHub release
    echo "Creating GitHub release..."
    gh release create "${TAG}" --generate-notes --title "Release ${TAG}"

    # Publish to crates.io
    echo "Publishing to crates.io..."
    cargo publish

    echo ""
    echo "Release ${TAG} complete!"
    echo "GitHub Actions is now building WASM runtimes and CLI binaries."
    echo "Check progress at: https://github.com/anistark/wasmhub/actions"

# Create a release without publishing to crates.io
# Usage: just release-github 0.2.0
release-github version:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION="{{version}}"
    TAG="v${VERSION}"

    echo "Creating GitHub release ${TAG}..."

    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Error: Working directory has uncommitted changes"
        exit 1
    fi

    read -p "Create tag ${TAG} and GitHub release? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi

    git tag -a "${TAG}" -m "Release ${TAG}"
    git push origin "${TAG}"
    gh release create "${TAG}" --generate-notes --title "Release ${TAG}"

    echo "GitHub release ${TAG} created!"
    echo "Check build progress at: https://github.com/anistark/wasmhub/actions"

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

# Generate global manifest.json from per-runtime manifests
manifest:
    ./scripts/generate-global-manifest.sh

# Build runtimes inside Docker container
docker-build-runtimes:
    docker run --rm -v "$(pwd):/workspace" wasmhub-builder ./scripts/build-all.sh
