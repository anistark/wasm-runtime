#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
RUNTIMES_DIR="${PROJECT_ROOT}/runtimes"

OPT_LEVEL="${OPT_LEVEL:-Oz}"
COMPRESS_GZIP="${COMPRESS_GZIP:-true}"
COMPRESS_BROTLI="${COMPRESS_BROTLI:-true}"

if ! command -v wasm-opt &> /dev/null; then
    echo "Warning: wasm-opt not found, skipping WASM optimization"
    echo "Install: https://github.com/WebAssembly/binaryen"
    SKIP_WASM_OPT="true"
else
    SKIP_WASM_OPT="false"
fi

echo "WASM Binary Optimization"
echo "========================"
echo "Optimization level: ${OPT_LEVEL}"
echo ""

TOTAL_BEFORE=0
TOTAL_AFTER=0

for wasm in "${RUNTIMES_DIR}"/*/*.wasm; do
    [[ -f "${wasm}" ]] || continue

    FILENAME=$(basename "${wasm}")
    SIZE_BEFORE=$(stat -f%z "${wasm}" 2>/dev/null || stat -c%s "${wasm}")
    TOTAL_BEFORE=$((TOTAL_BEFORE + SIZE_BEFORE))

    echo "Processing: ${FILENAME}"
    echo "  Original: $(numfmt --to=iec-i --suffix=B ${SIZE_BEFORE} 2>/dev/null || echo "${SIZE_BEFORE} bytes")"

    if [[ "${SKIP_WASM_OPT}" != "true" ]]; then
        OPTIMIZED="${wasm}.opt"
        wasm-opt "-${OPT_LEVEL}" --enable-bulk-memory --strip-debug -o "${OPTIMIZED}" "${wasm}"

        SIZE_AFTER=$(stat -f%z "${OPTIMIZED}" 2>/dev/null || stat -c%s "${OPTIMIZED}")
        SAVINGS=$(( (SIZE_BEFORE - SIZE_AFTER) * 100 / SIZE_BEFORE ))

        mv "${OPTIMIZED}" "${wasm}"
        echo "  Optimized: $(numfmt --to=iec-i --suffix=B ${SIZE_AFTER} 2>/dev/null || echo "${SIZE_AFTER} bytes") (-${SAVINGS}%)"
        TOTAL_AFTER=$((TOTAL_AFTER + SIZE_AFTER))
    else
        TOTAL_AFTER=$((TOTAL_AFTER + SIZE_BEFORE))
    fi

    if [[ "${COMPRESS_GZIP}" == "true" ]] && command -v gzip &> /dev/null; then
        gzip -9 -k -f "${wasm}"
        GZ_SIZE=$(stat -f%z "${wasm}.gz" 2>/dev/null || stat -c%s "${wasm}.gz")
        echo "  Gzip: $(numfmt --to=iec-i --suffix=B ${GZ_SIZE} 2>/dev/null || echo "${GZ_SIZE} bytes")"
    fi

    if [[ "${COMPRESS_BROTLI}" == "true" ]] && command -v brotli &> /dev/null; then
        brotli -9 -k -f "${wasm}"
        BR_SIZE=$(stat -f%z "${wasm}.br" 2>/dev/null || stat -c%s "${wasm}.br")
        echo "  Brotli: $(numfmt --to=iec-i --suffix=B ${BR_SIZE} 2>/dev/null || echo "${BR_SIZE} bytes")"
    fi

    echo ""
done

if [[ "${SKIP_WASM_OPT}" != "true" && ${TOTAL_BEFORE} -gt 0 ]]; then
    TOTAL_SAVINGS=$(( (TOTAL_BEFORE - TOTAL_AFTER) * 100 / TOTAL_BEFORE ))
    echo "Summary:"
    echo "  Before: $(numfmt --to=iec-i --suffix=B ${TOTAL_BEFORE} 2>/dev/null || echo "${TOTAL_BEFORE} bytes")"
    echo "  After:  $(numfmt --to=iec-i --suffix=B ${TOTAL_AFTER} 2>/dev/null || echo "${TOTAL_AFTER} bytes")"
    echo "  Saved:  ${TOTAL_SAVINGS}%"
fi

RUNTIME_DIR_PATH="${RUNTIMES_DIR}"
for manifest in "${RUNTIME_DIR_PATH}"/*/manifest.json; do
    [[ -f "${manifest}" ]] || continue

    LANG_DIR=$(dirname "${manifest}")

    if command -v jq &> /dev/null; then
        TMP=$(mktemp)
        jq --arg dir "${LANG_DIR}" '
            .versions |= with_entries(
                .value.size = (
                    .value.file as $f |
                    ($dir + "/" + $f) |
                    input_line_number
                ) // .value.size
            )
        ' "${manifest}" > /dev/null 2>&1 || true

        for wasm in "${LANG_DIR}"/*.wasm; do
            [[ -f "${wasm}" ]] || continue
            FNAME=$(basename "${wasm}")
            NEW_SIZE=$(stat -f%z "${wasm}" 2>/dev/null || stat -c%s "${wasm}")
            NEW_SHA=$(shasum -a 256 "${wasm}" | cut -d' ' -f1)

            jq --arg fname "${FNAME}" --argjson size "${NEW_SIZE}" --arg sha "${NEW_SHA}" '
                .versions |= with_entries(
                    if .value.file == $fname then .value.size = $size | .value.sha256 = $sha
                    else . end
                )
            ' "${manifest}" > "${TMP}"
            mv "${TMP}" "${manifest}"
        done
    fi
done

echo ""
echo "Optimization complete."
