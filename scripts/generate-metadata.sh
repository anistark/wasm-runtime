#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

usage() {
    echo "Usage: $0 --language LANG --version VER --file WASM_FILE [options]"
    echo ""
    echo "Required:"
    echo "  -l, --language LANG     Language (go, rust, nodejs, python, ruby, php)"
    echo "  -v, --version VERSION   Runtime version"
    echo "  -f, --file FILE         Path to WASM file"
    echo ""
    echo "Options:"
    echo "  --wasi VERSION          WASI version (default: wasip1)"
    echo "  --features FEATURES     Comma-separated features"
    echo "  -h, --help              Show this help"
    exit 1
}

LANGUAGE=""
VERSION=""
WASM_FILE=""
WASI_VERSION="wasip1"
FEATURES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--language) LANGUAGE="$2"; shift 2 ;;
        -v|--version) VERSION="$2"; shift 2 ;;
        -f|--file) WASM_FILE="$2"; shift 2 ;;
        --wasi) WASI_VERSION="$2"; shift 2 ;;
        --features) FEATURES="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "${LANGUAGE}" || -z "${VERSION}" || -z "${WASM_FILE}" ]]; then
    echo "Error: --language, --version, and --file are required"
    usage
fi

if [[ ! -f "${WASM_FILE}" ]]; then
    echo "Error: WASM file not found: ${WASM_FILE}"
    exit 1
fi

SIZE=$(stat -f%z "${WASM_FILE}" 2>/dev/null || stat -c%s "${WASM_FILE}")
SHA256=$(shasum -a 256 "${WASM_FILE}" | cut -d' ' -f1)
FILENAME=$(basename "${WASM_FILE}")
RELEASED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

RUNTIME_DIR=$(dirname "${WASM_FILE}")
MANIFEST_FILE="${RUNTIME_DIR}/manifest.json"

FEATURES_JSON="[]"
if [[ -n "${FEATURES}" ]]; then
    FEATURES_JSON=$(echo "${FEATURES}" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//' | sed 's/^/[/;s/$/]/')
fi

if [[ -f "${MANIFEST_FILE}" ]]; then
    TMP_FILE=$(mktemp)

    NEW_VERSION=$(cat <<EOF
{
    "file": "${FILENAME}",
    "size": ${SIZE},
    "sha256": "${SHA256}",
    "released": "${RELEASED}",
    "wasi": "${WASI_VERSION}",
    "features": ${FEATURES_JSON}
}
EOF
)

    if command -v jq &> /dev/null; then
        jq --argjson newver "${NEW_VERSION}" \
           --arg ver "${VERSION}" \
           '.versions[$ver] = $newver | .latest = $ver' \
           "${MANIFEST_FILE}" > "${TMP_FILE}"
        mv "${TMP_FILE}" "${MANIFEST_FILE}"
    else
        echo "Warning: jq not found, cannot update existing manifest"
        echo "New version metadata:"
        echo "${NEW_VERSION}"
    fi
else
    cat > "${MANIFEST_FILE}" <<EOF
{
    "language": "${LANGUAGE}",
    "latest": "${VERSION}",
    "versions": {
        "${VERSION}": {
            "file": "${FILENAME}",
            "size": ${SIZE},
            "sha256": "${SHA256}",
            "released": "${RELEASED}",
            "wasi": "${WASI_VERSION}",
            "features": ${FEATURES_JSON}
        }
    }
}
EOF
fi

echo "Metadata generated:"
echo "  Manifest: ${MANIFEST_FILE}"
echo "  Language: ${LANGUAGE}"
echo "  Version: ${VERSION}"
echo "  Size: ${SIZE} bytes"
echo "  SHA256: ${SHA256}"
