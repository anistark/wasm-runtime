#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <wasm_file> [options]"
    echo ""
    echo "Options:"
    echo "  --sha256 HASH     Verify SHA256 checksum"
    echo "  --run             Try to execute the binary"
    echo "  --args ARGS       Arguments to pass when running"
    echo "  -v, --verbose     Verbose output"
    echo "  -h, --help        Show this help"
    exit 1
}

WASM_FILE=""
EXPECTED_SHA256=""
RUN_BINARY="false"
RUN_ARGS=""
VERBOSE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sha256) EXPECTED_SHA256="$2"; shift 2 ;;
        --run) RUN_BINARY="true"; shift ;;
        --args) RUN_ARGS="$2"; shift 2 ;;
        -v|--verbose) VERBOSE="true"; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) WASM_FILE="$1"; shift ;;
    esac
done

if [[ -z "${WASM_FILE}" ]]; then
    echo "Error: WASM file required"
    usage
fi

if [[ ! -f "${WASM_FILE}" ]]; then
    echo "FAIL: File not found: ${WASM_FILE}"
    exit 1
fi

ERRORS=0

log() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "$@"
    fi
}

echo "Verifying: ${WASM_FILE}"
echo ""

log "Checking file exists..."
if [[ -f "${WASM_FILE}" ]]; then
    echo "✓ File exists"
else
    echo "✗ File not found"
    ((ERRORS++))
fi

log "Checking WASM magic number..."
MAGIC=$(xxd -l 4 -p "${WASM_FILE}" 2>/dev/null || od -A n -t x1 -N 4 "${WASM_FILE}" | tr -d ' ')
if [[ "${MAGIC}" == "0061736d" ]]; then
    echo "✓ Valid WASM magic number"
else
    echo "✗ Invalid WASM magic number: ${MAGIC}"
    ((ERRORS++))
fi

SIZE=$(stat -f%z "${WASM_FILE}" 2>/dev/null || stat -c%s "${WASM_FILE}")
echo "✓ File size: ${SIZE} bytes"

if [[ -n "${EXPECTED_SHA256}" ]]; then
    log "Verifying SHA256..."
    ACTUAL_SHA256=$(shasum -a 256 "${WASM_FILE}" | cut -d' ' -f1)
    if [[ "${ACTUAL_SHA256}" == "${EXPECTED_SHA256}" ]]; then
        echo "✓ SHA256 checksum matches"
    else
        echo "✗ SHA256 mismatch"
        echo "  Expected: ${EXPECTED_SHA256}"
        echo "  Actual:   ${ACTUAL_SHA256}"
        ((ERRORS++))
    fi
else
    SHA256=$(shasum -a 256 "${WASM_FILE}" | cut -d' ' -f1)
    echo "✓ SHA256: ${SHA256}"
fi

if command -v wasmtime &> /dev/null; then
    log "Validating with wasmtime..."
    if wasmtime compile --dry-run "${WASM_FILE}" 2>/dev/null; then
        echo "✓ Wasmtime validation passed"
    else
        echo "✗ Wasmtime validation failed"
        ((ERRORS++))
    fi

    if [[ "${RUN_BINARY}" == "true" ]]; then
        echo ""
        echo "Executing binary..."
        echo "---"
        if [[ -n "${RUN_ARGS}" ]]; then
            wasmtime run "${WASM_FILE}" -- ${RUN_ARGS}
        else
            timeout 5 wasmtime run "${WASM_FILE}" || true
        fi
        echo "---"
    fi
else
    echo "- Wasmtime not found, skipping runtime validation"
fi

echo ""
if [[ ${ERRORS} -eq 0 ]]; then
    echo "Result: PASS"
    exit 0
else
    echo "Result: FAIL (${ERRORS} errors)"
    exit 1
fi
