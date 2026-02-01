#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
RUNTIMES_DIR="${PROJECT_ROOT}/runtimes/rust"
BUILD_DIR="${PROJECT_ROOT}/build/rust"

RUST_VERSION="${RUST_VERSION:-1.84}"
TARGET="${TARGET:-wasm32-wasip1}"
OPTIMIZE="${OPTIMIZE:-true}"

usage() {
    echo "Usage: $0 [options] <cargo_project_dir>"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION   Rust version label (default: ${RUST_VERSION})"
    echo "  -o, --output NAME       Output filename (default: rust-VERSION.wasm)"
    echo "  -t, --target TARGET     Rust target (default: ${TARGET})"
    echo "  --no-optimize           Skip wasm-opt optimization"
    echo "  -h, --help              Show this help"
    exit 1
}

OUTPUT_NAME=""
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version) RUST_VERSION="$2"; shift 2 ;;
        -o|--output) OUTPUT_NAME="$2"; shift 2 ;;
        -t|--target) TARGET="$2"; shift 2 ;;
        --no-optimize) OPTIMIZE="false"; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done

if [[ -z "${PROJECT_DIR}" ]]; then
    echo "Error: Cargo project directory required"
    usage
fi

if [[ ! -f "${PROJECT_DIR}/Cargo.toml" ]]; then
    echo "Error: Cargo.toml not found in: ${PROJECT_DIR}"
    exit 1
fi

if ! rustup target list --installed | grep -q "${TARGET}"; then
    echo "Adding Rust target: ${TARGET}"
    rustup target add "${TARGET}"
fi

OUTPUT_NAME="${OUTPUT_NAME:-rust-${RUST_VERSION}.wasm}"
OUTPUT_PATH="${BUILD_DIR}/${OUTPUT_NAME}"

mkdir -p "${BUILD_DIR}"

echo "Building Rust runtime..."
echo "  Project: ${PROJECT_DIR}"
echo "  Target: ${TARGET}"
echo "  Output: ${OUTPUT_PATH}"

pushd "${PROJECT_DIR}" > /dev/null
cargo build --target "${TARGET}" --release
BINARY_NAME=$(cargo metadata --format-version 1 --no-deps | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
popd > /dev/null

BUILT_WASM="${PROJECT_DIR}/target/${TARGET}/release/${BINARY_NAME}.wasm"
if [[ ! -f "${BUILT_WASM}" ]]; then
    echo "Error: Built WASM not found at: ${BUILT_WASM}"
    exit 1
fi

cp "${BUILT_WASM}" "${OUTPUT_PATH}"

if [[ "${OPTIMIZE}" == "true" ]] && command -v wasm-opt &> /dev/null; then
    echo "Optimizing with wasm-opt..."
    wasm-opt -O3 "${OUTPUT_PATH}" -o "${OUTPUT_PATH}.opt"
    mv "${OUTPUT_PATH}.opt" "${OUTPUT_PATH}"
fi

SIZE=$(stat -f%z "${OUTPUT_PATH}" 2>/dev/null || stat -c%s "${OUTPUT_PATH}")
SHA256=$(shasum -a 256 "${OUTPUT_PATH}" | cut -d' ' -f1)

echo ""
echo "Build complete:"
echo "  File: ${OUTPUT_PATH}"
echo "  Size: ${SIZE} bytes"
echo "  SHA256: ${SHA256}"

mkdir -p "${RUNTIMES_DIR}"
cp "${OUTPUT_PATH}" "${RUNTIMES_DIR}/"

"${SCRIPT_DIR}/generate-metadata.sh" \
    --language rust \
    --version "${RUST_VERSION}" \
    --file "${RUNTIMES_DIR}/${OUTPUT_NAME}"
