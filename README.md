# 🚀 WasmHub

**Open-source WASM Hub of language runtimes**

Download and manage WASM runtimes for Node.js, Python, Ruby, PHP, Go, and more - all in one place.

[![Crates.io](https://img.shields.io/crates/v/wasmhub.svg)](https://crates.io/crates/wasmhub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/anistark/wasmhub/workflows/CI/badge.svg)](https://github.com/anistark/wasmhub/actions)
[![Build Runtimes](https://github.com/anistark/wasmhub/workflows/Build%20Runtimes/badge.svg)](https://github.com/anistark/wasmhub/actions/workflows/build-runtimes.yml)

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
wasmhub = "0.1"
```

```rust
use wasmhub::{RuntimeLoader, Language};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let loader = RuntimeLoader::new();

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
wasmhub get go@1.23
wasmhub get rust@1.82

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

- ✅ **Multi-language support** - Go, Rust (more coming soon)
- ✅ **Version management** - Pin to specific versions
- ✅ **Smart caching** - Download once, use forever
- ✅ **Type-safe API** - Rust library with compile-time guarantees
- ✅ **Fast downloads** - Parallel, resumable transfers
- ✅ **CDN distribution** - Served via jsDelivr for browser access
- ✅ **SHA256 verification** - Integrity checks built-in
- ✅ **Cross-platform** - Works on Windows, macOS, Linux

---

## 📦 Available Runtimes

| Language | Versions | Size | Status | About |
|----------|----------|------|--------|-------|
| **Go** | 1.23 | 261KB | 🚀 Upcoming Release | Built with TinyGo, supports filesystem, env, args, stdio |
| **Rust** | 1.82 | 76KB | 🚀 Upcoming Release |  Full std library support with wasm32-wasip1 target |
| **Node.js** | - | - | 🚧 Coming Soon | - |
| **Python** | - | - | 🚧 Coming Soon | - |
| **Ruby** | - | - | 🚧 Coming Soon | - |
| **PHP** | - | - | 🚧 Coming Soon | - |

*More languages and versions coming soon! Contributions welcome.* ✨

---

## 📥 Downloading Runtimes

WASM runtime binaries are built and published automatically on each [GitHub Release](https://github.com/anistark/wasmhub/releases).

### From GitHub Releases

```sh
# Download the latest Go runtime
curl -LO https://github.com/anistark/wasmhub/releases/latest/download/go-1.23.wasm

# Download a specific version's manifest
curl -LO https://github.com/anistark/wasmhub/releases/download/v0.1.0/manifest.json
```

### Using the CLI

```sh
# The CLI automatically fetches from releases
wasmhub get go@1.23
```

### Manifest Format

Each runtime has a `manifest.json` describing available versions:

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
// Load Node.js in browser
let nodejs_wasm = loader.get_runtime(Language::NodeJs, "20.2.0").await?;
// Run user's project in WASM VM
```

### 2. **Serverless Edge Functions**
Deploy language runtimes to Cloudflare Workers, Deno Deploy, etc.:
```sh
wasmhub get python@3.11.7
# Deploy to edge with Python support
```

### 3. **Testing Frameworks**
Run tests in isolated WASM environments:
```rust
// Test with specific Node.js version
let node18 = loader.get_runtime(Language::NodeJs, "18.19.0").await?;
run_tests_with_runtime(node18)?;
```

### 4. **Educational Platforms**
Create online code editors with multiple language support:
```javascript
// Student selects Python 3.12
const runtime = await fetchRuntime('python', '3.12.0');
executeCode(studentCode, runtime);
```

---

## 📖 Documentation

- **[API Documentation](https://docs.rs/wasmhub)** - Full Rust API reference
- **[Contributing Guide](CONTRIBUTING.md)** - Help build this project

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

- **GitHub Discussions:** [Ask questions, share ideas](https://github.com/anistark/wasmhub/discussions)
- **Twitter:** [@anistark](https://x.com/kranirudha)

---

## 📄 License

MIT License - see [LICENSE](./LICENSE) for details.

---

## 🙏 Acknowledgments

This project builds upon the amazing work of:
- [Pyodide](https://pyodide.org) - Python in WASM
- [ruby.wasm](https://github.com/ruby/ruby.wasm) - Ruby in WASM
- [CodeSandbox](https://codesandbox.io) - nodebox inspiration
- [Wasmer](https://wasmer.io) - WASM runtime ecosystem

---

## ⚡ Why WASM Runtime?

**The Problem:** Language runtimes for WASM are scattered across different projects. Finding, downloading, and managing them is painful.

**The Solution:** A single, centralized repository with:
- ✅ Versioned runtimes for multiple languages
- ✅ Consistent APIs (Rust library + CLI)
- ✅ CDN distribution for browsers
- ✅ Smart caching and integrity verification
- ✅ Open-source and community-driven

**Join us in making WASM runtimes accessible to everyone!** 🚀

---

**Made with ❤️ by [Kumar Anirudha](https://github.com/anistark)**
