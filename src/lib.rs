//! # WasmHub
//!
//! A library for downloading and managing WebAssembly runtimes for multiple languages.
//!
//! ## Features
//!
//! - Download and cache WASM runtimes for Node.js, Python, Ruby, PHP, Go, and Rust
//! - Automatic integrity verification using SHA256
//! - Local caching to avoid redundant downloads
//! - Support for multiple runtime versions
//! - Multiple CDN sources with automatic fallback
//!
//! ## Example
//!
//! ```no_run
//! use wasmhub::{RuntimeLoader, Language};
//!
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! let loader = RuntimeLoader::new()?;
//!
//! // Download a runtime (or get from cache)
//! let runtime = loader.get_runtime(Language::Python, "3.11.7").await?;
//! println!("Runtime path: {:?}", runtime.path);
//!
//! // List available runtimes
//! let manifest = loader.list_available().await?;
//! for (lang, info) in &manifest.languages {
//!     println!("{}: latest = {}", lang, info.latest);
//! }
//!
//! // Get latest version for a language
//! let latest = loader.get_latest_version(Language::Python).await?;
//! println!("Latest Python: {}", latest);
//! # Ok(())
//! # }
//! ```

pub mod cache;
pub mod error;
pub mod loader;
pub mod manifest;
pub mod runtime;

pub use cache::CacheManager;
pub use error::{Error, Result};
pub use loader::{CdnSource, RuntimeLoader, RuntimeLoaderBuilder};
pub use manifest::{GlobalManifest, RuntimeInfo, RuntimeManifest, RuntimeVersion};
pub use runtime::{Language, Runtime};
