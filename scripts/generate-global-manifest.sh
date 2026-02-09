#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
RUNTIMES_DIR="${PROJECT_ROOT}/runtimes"
OUTPUT="${PROJECT_ROOT}/manifest.json"

WASMHUB_VERSION=$(grep '^version' "${PROJECT_ROOT}/Cargo.toml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

declare -A SOURCES=(
    ["go"]="https://go.dev/"
    ["rust"]="https://www.rust-lang.org/"
    ["nodejs"]="https://nodejs.org/"
    ["python"]="https://python.org/"
    ["ruby"]="https://www.ruby-lang.org/"
    ["php"]="https://www.php.net/"
)

declare -A LICENSES=(
    ["go"]="BSD-3-Clause"
    ["rust"]="MIT/Apache-2.0"
    ["nodejs"]="MIT"
    ["python"]="PSF-2.0"
    ["ruby"]="BSD-2-Clause"
    ["php"]="PHP-3.01"
)

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

LANGUAGES_JSON="{}"

for manifest_file in "${RUNTIMES_DIR}"/*/manifest.json; do
    [[ -f "${manifest_file}" ]] || continue

    LANG=$(jq -r '.language' "${manifest_file}")
    LATEST=$(jq -r '.latest' "${manifest_file}")
    VERSIONS=$(jq -r '.versions | keys[]' "${manifest_file}" | jq -R -s 'split("\n") | map(select(length > 0))')

    SOURCE="${SOURCES[$LANG]:-"unknown"}"
    LICENSE="${LICENSES[$LANG]:-"unknown"}"

    LANG_ENTRY=$(jq -n \
        --arg latest "${LATEST}" \
        --argjson versions "${VERSIONS}" \
        --arg source "${SOURCE}" \
        --arg license "${LICENSE}" \
        '{latest: $latest, versions: $versions, source: $source, license: $license}')

    LANGUAGES_JSON=$(echo "${LANGUAGES_JSON}" | jq --arg lang "${LANG}" --argjson entry "${LANG_ENTRY}" '.[$lang] = $entry')
done

jq -n \
    --arg version "${WASMHUB_VERSION}" \
    --arg build_date "${BUILD_DATE}" \
    --argjson languages "${LANGUAGES_JSON}" \
    '{version: $version, build_date: $build_date, languages: $languages}' > "${OUTPUT}"

echo "Global manifest generated: ${OUTPUT}"
jq . "${OUTPUT}"
