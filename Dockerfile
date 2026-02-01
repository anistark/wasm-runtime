FROM debian:bookworm-slim

LABEL maintainer="Ani <github.com/anistark>"
LABEL description="WasmHub build environment with WASI SDK, TinyGo, and Rust"

ARG WASI_SDK_VERSION=24
ARG TINYGO_VERSION=0.34.0
ARG RUST_VERSION=stable
ARG WASMTIME_VERSION=27.0.0

ENV DEBIAN_FRONTEND=noninteractive
ENV WASI_SDK_PATH=/opt/wasi-sdk
ENV TINYGO_ROOT=/opt/tinygo
ENV PATH="${TINYGO_ROOT}/bin:${WASI_SDK_PATH}/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION}/wasi-sdk-${WASI_SDK_VERSION}.0-x86_64-linux.tar.gz" \
    | tar -xzf - -C /opt \
    && mv /opt/wasi-sdk-${WASI_SDK_VERSION}.0-x86_64-linux ${WASI_SDK_PATH}

RUN curl -fsSL "https://github.com/tinygo-org/tinygo/releases/download/v${TINYGO_VERSION}/tinygo${TINYGO_VERSION}.linux-amd64.tar.gz" \
    | tar -xzf - -C /opt

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup target add wasm32-wasip1

RUN curl -fsSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VERSION}/wasmtime-v${WASMTIME_VERSION}-x86_64-linux.tar.xz" \
    | tar -xJf - -C /opt \
    && ln -s /opt/wasmtime-v${WASMTIME_VERSION}-x86_64-linux/wasmtime /usr/local/bin/wasmtime

WORKDIR /workspace

RUN echo "WASI SDK: ${WASI_SDK_VERSION}" && \
    echo "TinyGo: $(tinygo version)" && \
    echo "Rust: $(rustc --version)" && \
    echo "Cargo: $(cargo --version)" && \
    echo "Wasmtime: $(wasmtime --version)" && \
    echo "wasm32-wasip1 target: $(rustup target list --installed | grep wasm)"

CMD ["/bin/bash"]
