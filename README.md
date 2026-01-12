# 🚀 WasmHub

**Open-source WASM Hub of language runtimes**

Download and manage WASM runtimes for Node.js, Python, Ruby, PHP, Go, and more - all in one place.

[![Crates.io](https://img.shields.io/crates/v/wasmhub.svg)](https://crates.io/crates/wasmhub)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/anistark/wasmhub/workflows/CI/badge.svg)](https://github.com/anistark/wasmhub/actions)

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

    // Download Node.js v20.2.0 (auto-cached)
    let nodejs = loader.get_runtime(Language::NodeJs, "20.2.0").await?;

    println!("Runtime at: {}", nodejs.path.display());
    Ok(())
}
```

### As a CLI Tool

```sh
# Install
cargo install wasmhub --features cli

# Download runtimes
wasmhub get nodejs@20.2.0
wasmhub get python@3.11.7

# List available
wasmhub list

# Show info
wasmhub info nodejs
```

### Via CDN (Browser)

```javascript
// Direct download
const url = 'https://cdn.jsdelivr.net/gh/anistark/wasmhub@latest/runtimes/nodejs/v20.2.0.wasm';
const response = await fetch(url);
const wasmBytes = await response.arrayBuffer();
```

---

## 🌟 Features

- ✅ **Multi-language support** - Node.js, Python, Ruby, PHP, Go, Rust
- ✅ **Version management** - Pin to specific versions
- ✅ **Smart caching** - Download once, use forever
- ✅ **Type-safe API** - Rust library with compile-time guarantees
- ✅ **Fast downloads** - Parallel, resumable transfers
- ✅ **CDN distribution** - Served via jsDelivr for browser access
- ✅ **SHA256 verification** - Integrity checks built-in
- ✅ **Cross-platform** - Works on Windows, macOS, Linux

---

## 📦 Available Runtimes

| Language | Versions | Size | Source |
|----------|----------|------|--------|
| **Node.js** | 18.x, 20.x, 22.x | ~50MB | [nodebox](https://github.com/codesandbox/nodebox) |
| **Python** | 3.11.x, 3.12.x | ~35MB | [Pyodide](https://pyodide.org) |
| **Ruby** | 3.2.x | ~20MB | [ruby.wasm](https://github.com/ruby/ruby.wasm) |
| **PHP** | 8.3.x | ~15MB | [php-wasm](https://wasmer.io) |
| **Go** | 1.21.x | ~30MB | [TinyGo](https://tinygo.org) |
| **Rust** | Latest | Varies | Native WASM target |

*More languages coming soon! PRs welcome.*

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
