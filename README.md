# 🚀 WasmHub

**Open-source WASM Hub of language runtimes**

Download and manage WASM runtimes for Node.js, Python, Ruby, PHP, Go, and more — all in one place.

[![Crates.io](https://img.shields.io/crates/v/wasmhub.svg)](https://crates.io/crates/wasmhub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/anistark/wasmhub/workflows/CI/badge.svg)](https://github.com/anistark/wasmhub/actions)
[![Build Runtimes](https://github.com/anistark/wasmhub/workflows/Build%20Runtimes/badge.svg)](https://github.com/anistark/wasmhub/actions/workflows/build-runtimes.yml)
[![Docs](https://github.com/anistark/wasmhub/actions/workflows/docs.yml/badge.svg)](https://anistark.github.io/wasmhub/)

---

## 🎯 What is this?

A centralized, open-source repository providing **versioned WASM language runtimes** that can be:
- Downloaded once, cached forever
- Used in any Rust project as a library
- Accessed via CLI tool
- Fetched via CDN for browser usage

**Think of it as:** A package registry for WASM language runtimes (like npm, but for runtime binaries).

---

## ⚡ Quick Start

### As a Library (Rust)

```toml
# Cargo.toml
[dependencies]
wasmhub = "0.3"
tokio = { version = "1", features = ["full"] }
```

```rust
use wasmhub::{RuntimeLoader, Language};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let loader = RuntimeLoader::new()?;

    // Download Go 1.23 (auto-cached)
    let go = loader.get_runtime(Language::Go, "1.23").await?;

    println!("Runtime at: {}", go.path.display());
    Ok(())
}
```

### As a CLI Tool

```sh
# Install
cargo install wasmhub --features cli

# Download runtimes
wasmhub get go 1.23
wasmhub get rust 1.82

# List available
wasmhub list

# Show info
wasmhub info go
```

### Via CDN (Browser)

```javascript
// From GitHub Releases
const url = 'https://github.com/anistark/wasmhub/releases/latest/download/go-1.23.wasm';
const response = await fetch(url);
const wasmBytes = await response.arrayBuffer();
```

---

## 🌟 Features

- ✅ **Multi-language support** — Go, Rust, Node.js (more coming soon)
- ✅ **Version management** — Pin to specific versions
- ✅ **Smart caching** — Download once, use forever
- ✅ **Type-safe API** — Rust library with compile-time guarantees
- ✅ **Multi-CDN fallback** — GitHub Releases + jsDelivr with automatic failover
- ✅ **Retry with backoff** — Exponential backoff on transient failures
- ✅ **SHA256 verification** — Integrity checks on every download
- ✅ **Cross-platform** — Works on Windows, macOS, Linux

---

## 📦 Available Runtimes

| Language | Versions | Size | Status | About |
|----------|----------|------|--------|-------|
| **Go** | 1.23 | 261 KB | ✅ Available | Built with TinyGo, supports filesystem, env, args, stdio |
| **Rust** | 1.82 | 76 KB | ✅ Available | Full std library support with wasm32-wasip1 target |
| **Node.js** | 20 | ~1.1 MB | 🚧 Alpha | Built with QuickJS (ES2020), supports eval, run, stdio, env, filesystem via WASI, a CommonJS stdlib (`path`, `fs`, `crypto`, `url`, `stream`, `buffer`, …), and inbound `net`/`http` servers over a host-provided socket |
| **swc** | 73 | ~2.4 MB | 🚧 Alpha | TypeScript → JavaScript transpiler (tool, not a language runtime): strips types, lowers TSX and ES modules to CommonJS for the Node.js runtime. MVP-only WASM for interpreter compatibility |
| **Python** | — | — | 🔜 Coming Soon | — |
| **Ruby** | — | — | 🔜 Coming Soon | — |
| **PHP** | — | — | 🔜 Coming Soon | — |

All four runtimes target **WASI Preview 1** (`wasip1`). Node.js v20 and swc are in alpha.

*More languages and versions coming soon! Contributions welcome.* ✨

---

## 📥 CLI Reference

### Installation

```sh
cargo install wasmhub --features cli
```

### Commands

```sh
wasmhub get <language> [version]          # Download runtime (default: latest)
wasmhub get <language> <version> --force  # Force re-download
wasmhub list [language]                   # List available runtimes
wasmhub info <language> [version]         # Show runtime details
wasmhub cache show                        # Show cache contents
wasmhub cache clear <language> <version>  # Clear specific cached runtime
wasmhub cache clear-all [--yes]           # Clear all cache
```

### Language Aliases

| Language | Accepted values |
|----------|----------------|
| Node.js | `nodejs`, `node`, `node.js` |
| Python | `python`, `py` |
| Ruby | `ruby`, `rb` |
| PHP | `php` |
| Go | `go`, `golang` |
| Rust | `rust`, `rs` |
| swc | `swc` |

### Examples

```sh
# Download latest Go runtime
wasmhub get go

# Download specific version
wasmhub get rust 1.82

# Force re-download even if cached
wasmhub get go 1.23 --force

# See what's cached locally
wasmhub cache show

# Clear everything
wasmhub cache clear-all --yes
```

---

## 📚 Library Usage

```rust
use wasmhub::{RuntimeLoader, Language};

#[tokio::main]
async fn main() -> wasmhub::Result<()> {
    let loader = RuntimeLoader::new()?;

    // Download or get from cache
    let runtime = loader.get_runtime(Language::Go, "1.23").await?;
    println!("Path: {}", runtime.path.display());
    println!("SHA256: {}", runtime.sha256);

    // List available runtimes
    let manifest = loader.list_available().await?;
    for (lang, info) in &manifest.languages {
        println!("{}: latest = {}", lang, info.latest);
    }

    // Get latest version
    let latest = loader.get_latest_version(Language::Go).await?;
    println!("Latest Go: {}", latest);

    // Cache management
    loader.clear_cache(Language::Go, "1.23")?;
    loader.clear_all_cache()?;

    Ok(())
}
```

### Builder Configuration

```rust
use wasmhub::{RuntimeLoader, CdnSource};
use std::path::PathBuf;

let loader = RuntimeLoader::builder()
    .cache_dir(PathBuf::from("/tmp/my-cache"))
    .cdn_sources(vec![CdnSource::GitHubReleases])
    .max_retries(5)
    .initial_backoff_ms(1000)
    .max_backoff_ms(60_000)
    .build()?;
```

### Cargo Features

| Feature | What it enables | Default |
|---------|----------------|---------|
| *(none)* | Library only | ✅ |
| `progress` | Download progress bars (`indicatif`) | No |
| `cli` | CLI binary + `clap`, `anyhow`, `colored` + `progress` | No |

---

## 📥 Downloading Runtimes

WASM runtime binaries are built and published automatically on each [GitHub Release](https://github.com/anistark/wasmhub/releases).

### From GitHub Releases

```sh
# Download the latest Go runtime
curl -LO https://github.com/anistark/wasmhub/releases/latest/download/go-1.23.wasm

# Download the global manifest
curl -LO https://github.com/anistark/wasmhub/releases/latest/download/manifest.json
```

### Manifest Format

Each runtime has a per-language `manifest.json`:

```json
{
    "language": "go",
    "latest": "1.23",
    "versions": {
        "1.23": {
            "file": "go-1.23.wasm",
            "size": 266712,
            "sha256": "efa1e13f39dfd3783d0eff5669088ab99a1ea1d38ac79f29b02e2ad8ddfea29d",
            "released": "2026-02-03T13:23:13Z",
            "wasi": "wasip1",
            "features": []
        }
    }
}
```

---

## 🚀 Use Cases

### 1. **Browser-Based Development Environments**
Build tools like StackBlitz/CodeSandbox without the proprietary runtime:
```rust
let nodejs_wasm = loader.get_runtime(Language::NodeJs, "20.2.0").await?;
```

### 2. **Serverless Edge Functions**
Deploy language runtimes to Cloudflare Workers, Deno Deploy, etc.:
```sh
wasmhub get python 3.11.7
```

### 3. **Testing Frameworks**
Run tests in isolated WASM environments:
```rust
let node18 = loader.get_runtime(Language::NodeJs, "18.19.0").await?;
run_tests_with_runtime(node18)?;
```

### 4. **Educational Platforms**
Create online code editors with multiple language support:
```javascript
const runtime = await fetchRuntime('python', '3.12.0');
executeCode(studentCode, runtime);
```

---

## 📖 Documentation

- **[Docs Site](https://anistark.github.io/wasmhub/)** — Getting started, CLI reference, library guide, architecture _(coming soon)_
- **[API Documentation](https://docs.rs/wasmhub)** — Full Rust API reference
- **[wasmrun Documentation](https://wasmrun.readthedocs.io/)** — WASMRUN docs, and guide
- **[llms.txt](https://anistark.github.io/wasmhub/llms.txt)** / **[llms-full.txt](https://anistark.github.io/wasmhub/llms-full.txt)** — LLM-friendly index and full-content dump of the docs

---

## 🤝 Contributing

We welcome contributions! This project aims to be **community-driven**.

**How to help:**
- 🐛 Report bugs or request features via [Issues](https://github.com/anistark/wasmhub/issues)
- 🔧 Submit PRs for new runtimes or improvements
- 📖 Improve documentation
- ⭐ Star the repo to show support

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🌐 Community & Support

- **Join:** [Discord](https://discord.gg/AJMEeFXxXy)
- **Follow:** [@anistark](https://x.com/kranirudha)


---

## 📄 License

MIT License — see [LICENSE](./LICENSE) for details.

---

## 🙏 Acknowledgments

This project builds upon the amazing work of:
- [Pyodide](https://pyodide.org) — Python in WASM
- [ruby.wasm](https://github.com/ruby/ruby.wasm) — Ruby in WASM
- [CodeSandbox](https://codesandbox.io) — nodebox inspiration
- [Wasmer](https://wasmer.io) — WASM runtime ecosystem

---

**Made with ❤️ by [Kumar Anirudha](https://github.com/anistark)**
