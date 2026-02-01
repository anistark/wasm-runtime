#!/usr/bin/env bash
set -euo pipefail

WASI_SDK_VERSION="${WASI_SDK_VERSION:-24}"
INSTALL_DIR="${INSTALL_DIR:-/opt/wasi-sdk}"

ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "${ARCH}" in
    x86_64|amd64) ARCH="x86_64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: ${ARCH}"; exit 1 ;;
esac

case "${OS}" in
    linux) OS_SUFFIX="linux" ;;
    darwin) OS_SUFFIX="macos" ;;
    *) echo "Unsupported OS: ${OS}"; exit 1 ;;
esac

TARBALL="wasi-sdk-${WASI_SDK_VERSION}.0-${ARCH}-${OS_SUFFIX}.tar.gz"
URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}/${TARBALL}"

echo "Downloading WASI SDK ${WASI_SDK_VERSION} for ${OS_SUFFIX}-${ARCH}..."
curl -fsSL "${URL}" -o "/tmp/${TARBALL}"

echo "Extracting to ${INSTALL_DIR}..."
sudo mkdir -p "${INSTALL_DIR}"
sudo tar -xzf "/tmp/${TARBALL}" -C "$(dirname "${INSTALL_DIR}")"
sudo mv "$(dirname "${INSTALL_DIR}")/wasi-sdk-${WASI_SDK_VERSION}.0-${ARCH}-${OS_SUFFIX}" "${INSTALL_DIR}"

rm "/tmp/${TARBALL}"

echo "WASI SDK ${WASI_SDK_VERSION} installed to ${INSTALL_DIR}"
echo "Add to your shell profile:"
echo "  export WASI_SDK_PATH=${INSTALL_DIR}"
echo "  export PATH=\${WASI_SDK_PATH}/bin:\${PATH}"
