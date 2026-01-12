# Contributing to WasmHub

Thank you for your interest in contributing! This project aims to be community-driven.

## 📁 Project Structure

```sh
wasmhub/
├── src/
│   ├── lib.rs                       # 📦 Library code
│   └── bin/
│       └── wasmhub.rs               # 🔧 CLI binary (feature-gated)
│
├── runtimes/                        # 📁 WASM binaries (to be added)
│   ├── nodejs/
│   ├── python/
│   ├── ruby/
│   ├── php/
│   └── go/
│
├── .github/workflows/
│   └── ci.yml                       # ✅ CI pipeline
│
├── Cargo.toml                       # 📦 Package manifest
├── justfile                         # 🛠️ Build commands
├── README.md                        # 📖 User-facing docs
├── CONTRIBUTING.md                  # 👥 This file
├── LICENSE                          # ⚖️ MIT License
└── .gitignore                       # 🚫 Git ignore rules
```

The project is a single Rust crate with:
- **Library API** (`src/lib.rs`) - Can be used programmatically
- **CLI tool** (`src/bin/wasmhub.rs`) - Enabled with `--features cli`

## 🚀 Ways to Contribute

1. **Report Bugs** - Open an issue with reproduction steps
2. **Request Features** - Suggest new runtimes or improvements
3. **Submit PRs** - Fix bugs, add runtimes, improve docs
4. **Improve Documentation** - Help others understand the project
5. **Share** - Star the repo, tell others about it

## 🔧 Development Setup

### Prerequisites

- Rust 1.85+ (`rustup install stable`)
- Git
- Just (optional, for convenient build commands: `cargo install just`)

### Clone & Build

```sh
# Clone repository
git clone https://github.com/anistark/wasmhub.git
cd wasmhub

# Build library only
cargo build

# Build library + CLI
cargo build --features cli

# Run tests
cargo test

# Run CLI locally
cargo run --features cli -- --help

# Install CLI globally
cargo install --path . --features cli
```

## 📝 Code Style

```sh
# Format code
just format

# Lint code
just lint

# Auto-fix linting issues
just lint-fix
```

All PRs must pass formatting and linting checks.

## 🧪 Testing

Write tests for all new features:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_language_from_str() {
        assert_eq!(Language::from_str("nodejs"), Some(Language::NodeJs));
        assert_eq!(Language::from_str("unknown"), None);
    }
}
```

Run tests:
```sh
cargo test
```

## 📦 Adding a New Runtime

1. **Download the WASM binary** to `runtimes/<language>/`
2. **Create manifest.json** with version info
3. **Update global manifest.json**
4. **Add to `Language` enum** in `src/runtime.rs`
5. **Write tests**
6. **Update README.md**
7. **Submit PR**

Example:
```sh
# Add Java runtime
mkdir -p runtimes/java
# Download java-21.0.0.wasm
# Create runtimes/java/manifest.json
# Update Language enum
git commit -am "Add Java runtime support"
```

## 🐛 Reporting Bugs

Open an issue with:
- **Description** - What went wrong?
- **Steps to reproduce**
- **Expected behavior**
- **Actual behavior**
- **Environment** - OS, Rust version, etc.

## 💡 Feature Requests

Open an issue with:
- **Use case** - Why is this needed?
- **Proposed solution**
- **Alternatives considered**

## 🔀 Pull Request Process

1. **Fork** the repository
2. **Create a branch** - `git checkout -b feature/my-feature`
3. **Make changes** - Follow code style
4. **Write tests** - Ensure coverage
5. **Update docs** - If needed
6. **Commit** - Use clear commit messages
7. **Push** - `git push origin feature/my-feature`
8. **Open PR** - Fill out the template

### PR Checklist

- [ ] Code follows Rust style guide (`cargo fmt`)
- [ ] No clippy warnings (`cargo clippy`)
- [ ] Tests added and passing (`cargo test`)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)

## 📜 Commit Messages

Use conventional commits:

```
feat: add Java runtime support
fix: correct cache path on Windows
docs: update CLI usage examples
test: add integration tests for loader
chore: update dependencies
```

## 🏷️ Issue Labels

- `good-first-issue` - Great for newcomers
- `help-wanted` - Need community help
- `bug` - Something isn't working
- `enhancement` - New feature request
- `documentation` - Docs improvements

## ⚖️ Code of Conduct

Be respectful, inclusive, and collaborative. We're building this together.

## 📞 Questions?

- Open a [Discussion](https://github.com/anistark/wasmhub/discussions)
- Ask on Discord (coming soon)
- Email: ani@anistark.com

## 💡 Quick Reference

### Common Commands

Using justfile (recommended):

```sh
# Show all available commands
just --list

# Format code
just format

# Lint code
just lint

# Auto-fix lint issues
just lint-fix

# Check compilation
just check

# Build library
just build

# Build with all features
just build-all

# Run tests
just test

# Run all CI checks locally
just ci

# Install CLI globally
just install
```

Or using cargo directly:

```sh
# Build everything (library + CLI)
cargo build --all-features

# Run all tests
cargo test

# Format code
cargo fmt --all

# Lint code
cargo clippy --all-features

# Run CLI locally
cargo run --features cli -- list

# Check documentation
cargo doc --open

# Build release binary
cargo build --release --features cli
```

### Project Layout

- **src/lib.rs** - Public API for the library
- **src/bin/wasmhub.rs** - CLI application code
- **runtimes/** - Downloaded WASM runtime binaries
- **Cargo.toml** - Package manifest with `cli` feature flag

### Feature Flags

- **default** - Library only, no CLI
- **cli** - Includes CLI binary with `clap` argument parsing

Thank you for contributing! 🎉
