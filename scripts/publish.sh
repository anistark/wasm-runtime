#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run           Build and verify without creating a release"
    echo "  --skip-build        Skip Docker build (use existing binaries)"
    echo "  --skip-verify       Skip binary verification"
    echo "  --skip-optimize     Skip wasm-opt optimization"
    echo "  -h, --help          Show this help"
    exit 1
}

DRY_RUN="false"
SKIP_BUILD="false"
SKIP_VERIFY="false"
SKIP_OPTIMIZE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN="true"; shift ;;
        --skip-build) SKIP_BUILD="true"; shift ;;
        --skip-verify) SKIP_VERIFY="true"; shift ;;
        --skip-optimize) SKIP_OPTIMIZE="true"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

VERSION=$(grep '^version' "${PROJECT_ROOT}/Cargo.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
TAG="v${VERSION}"

echo "WasmHub Publish"
echo "==============="
echo "Version: ${VERSION}"
echo "Tag: ${TAG}"
echo "Dry run: ${DRY_RUN}"
echo ""

if [[ -n "$(git -C "${PROJECT_ROOT}" status --porcelain)" ]]; then
    echo "Error: Working directory has uncommitted changes"
    exit 1
fi

if [[ "${SKIP_BUILD}" != "true" ]]; then
    echo "==> Building runtimes in Docker..."
    docker run --rm \
        -v "${PROJECT_ROOT}:/workspace" \
        -w /workspace \
        wasmhub-builder:latest \
        ./scripts/build-all.sh
    echo ""
fi

if [[ "${SKIP_OPTIMIZE}" != "true" ]]; then
    echo "==> Optimizing WASM binaries..."
    "${SCRIPT_DIR}/optimize-wasm.sh"
    echo ""
fi

if [[ "${SKIP_VERIFY}" != "true" ]]; then
    echo "==> Verifying binaries..."
    ERRORS=0
    for wasm in "${PROJECT_ROOT}"/runtimes/*/*.wasm; do
        [[ -f "${wasm}" ]] || continue
        if ! "${SCRIPT_DIR}/verify-binary.sh" "${wasm}"; then
            ((ERRORS++))
        fi
        echo ""
    done

    if [[ ${ERRORS} -gt 0 ]]; then
        echo "Error: ${ERRORS} binary verification(s) failed"
        exit 1
    fi
    echo "All binaries verified."
    echo ""
fi

echo "==> Preparing release assets..."
RELEASE_DIR="${PROJECT_ROOT}/release-assets"
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"

find "${PROJECT_ROOT}/runtimes" -name "*.wasm" -exec cp {} "${RELEASE_DIR}/" \;

for manifest in "${PROJECT_ROOT}"/runtimes/*/manifest.json; do
    [[ -f "${manifest}" ]] || continue
    lang=$(basename "$(dirname "${manifest}")")
    cp "${manifest}" "${RELEASE_DIR}/${lang}-manifest.json"
done

cp "${PROJECT_ROOT}/manifest.json" "${RELEASE_DIR}/manifest.json"

cd "${RELEASE_DIR}"
shasum -a 256 * > SHA256SUMS
cd "${PROJECT_ROOT}"

echo "Release assets:"
ls -lh "${RELEASE_DIR}/"
echo ""

NOTES=$(cat <<EOF
## WasmHub ${TAG}

### WASM Runtimes
$(for wasm in "${RELEASE_DIR}"/*.wasm; do
    [[ -f "${wasm}" ]] || continue
    name=$(basename "${wasm}")
    size=$(du -h "${wasm}" | cut -f1)
    echo "- \`${name}\` (${size})"
done)

### Checksums
See \`SHA256SUMS\` in the release assets for verification.

### Installation
\`\`\`bash
cargo install wasmhub --features cli
\`\`\`
EOF
)

if [[ "${DRY_RUN}" == "true" ]]; then
    echo "==> DRY RUN: Skipping release creation"
    echo ""
    echo "Release notes preview:"
    echo "${NOTES}"
    echo ""
    echo "Dry run complete. Assets are in: ${RELEASE_DIR}/"
    exit 0
fi

echo "==> Creating release ${TAG}..."
echo ""
echo "This will:"
echo "  1. Create git tag ${TAG}"
echo "  2. Push tag to origin"
echo "  3. Create GitHub release with assets"
echo ""
read -p "Proceed? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 1
fi

git -C "${PROJECT_ROOT}" tag -a "${TAG}" -m "Release ${TAG}"
git -C "${PROJECT_ROOT}" push origin "${TAG}"

gh release create "${TAG}" \
    --title "Release ${TAG}" \
    --notes "${NOTES}" \
    "${RELEASE_DIR}"/*

echo ""
echo "Release ${TAG} published!"
echo "GitHub Actions will build CLI binaries automatically."
echo "Check: https://github.com/anistark/wasmhub/actions"
