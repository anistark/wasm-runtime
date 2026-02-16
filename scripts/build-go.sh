#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
RUNTIMES_DIR="${PROJECT_ROOT}/runtimes/go"
BUILD_DIR="${PROJECT_ROOT}/build/go"

GO_VERSION="${GO_VERSION:-1.23}"
TINYGO_TARGET="${TINYGO_TARGET:-wasip1}"
OPTIMIZE="${OPTIMIZE:-true}"

usage() {
    echo "Usage: $0 [options] <source_file>"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION   Go version label (default: ${GO_VERSION})"
    echo "  -o, --output NAME       Output filename (default: go-VERSION.wasm)"
    echo "  -t, --target TARGET     TinyGo target (default: ${TINYGO_TARGET})"
    echo "  --no-optimize           Skip wasm-opt optimization"
    echo "  -h, --help              Show this help"
    exit 1
}

OUTPUT_NAME=""
SOURCE_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version) GO_VERSION="$2"; shift 2 ;;
        -o|--output) OUTPUT_NAME="$2"; shift 2 ;;
        -t|--target) TINYGO_TARGET="$2"; shift 2 ;;
        --no-optimize) OPTIMIZE="false"; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) SOURCE_FILE="$1"; shift ;;
    esac
done

if [[ -z "${SOURCE_FILE}" ]]; then
    echo "Error: Source file required"
    usage
fi

if [[ ! -f "${SOURCE_FILE}" ]]; then
    echo "Error: Source file not found: ${SOURCE_FILE}"
    exit 1
fi

if ! command -v tinygo &> /dev/null; then
    echo "Error: TinyGo not found. Install TinyGo or use Docker environment."
    exit 1
fi

OUTPUT_NAME="${OUTPUT_NAME:-go-${GO_VERSION}.wasm}"
OUTPUT_PATH="${BUILD_DIR}/${OUTPUT_NAME}"

mkdir -p "${BUILD_DIR}"

echo "Building Go runtime..."
echo "  Source: ${SOURCE_FILE}"
echo "  Target: ${TINYGO_TARGET}"
echo "  Output: ${OUTPUT_PATH}"

tinygo build \
    -target="${TINYGO_TARGET}" \
    -opt=2 \
    -no-debug \
    -o "${OUTPUT_PATH}" \
    "${SOURCE_FILE}"

if [[ "${OPTIMIZE}" == "true" ]] && command -v wasm-opt &> /dev/null; then
    echo "Optimizing with wasm-opt..."
    wasm-opt -O3 --enable-bulk-memory "${OUTPUT_PATH}" -o "${OUTPUT_PATH}.opt"
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
    --language go \
    --version "${GO_VERSION}" \
    --file "${RUNTIMES_DIR}/${OUTPUT_NAME}"
