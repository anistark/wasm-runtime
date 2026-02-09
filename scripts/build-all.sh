#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

BUILD_GO="${BUILD_GO:-true}"
BUILD_RUST="${BUILD_RUST:-true}"
VERIFY="${VERIFY:-true}"

echo "WasmHub Runtime Builder"
echo "======================"
echo ""

if [[ "${BUILD_GO}" == "true" ]]; then
    if [[ -f "${PROJECT_ROOT}/runtimes/go/main.go" ]]; then
        echo "Building Go runtime..."
        "${SCRIPT_DIR}/build-go.sh" "${PROJECT_ROOT}/runtimes/go/main.go"
        echo ""
    else
        echo "Skipping Go: runtimes/go/main.go not found"
    fi
fi

if [[ "${BUILD_RUST}" == "true" ]]; then
    if [[ -d "${PROJECT_ROOT}/runtimes/rust" ]]; then
        echo "Building Rust runtime..."
        "${SCRIPT_DIR}/build-rust.sh" "${PROJECT_ROOT}/runtimes/rust"
        echo ""
    else
        echo "Skipping Rust: runtimes/rust not found"
    fi
fi

if [[ "${VERIFY}" == "true" ]]; then
    echo ""
    echo "Verifying built runtimes..."
    echo ""

    for wasm in "${PROJECT_ROOT}"/runtimes/*/*.wasm; do
        if [[ -f "${wasm}" ]]; then
            "${SCRIPT_DIR}/verify-binary.sh" "${wasm}"
            echo ""
        fi
    done
fi

echo "Generating global manifest..."
"${SCRIPT_DIR}/generate-global-manifest.sh"
echo ""

echo "Build complete!"
