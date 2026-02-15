use crate::cache::CacheManager;
use crate::error::{Error, Result};
use crate::manifest::{GlobalManifest, RuntimeManifest};
use crate::runtime::{Language, Runtime};
use reqwest::Client;
use std::path::PathBuf;
use std::time::Duration;

#[cfg(feature = "progress")]
use futures_util::StreamExt;

const GITHUB_RELEASES_BASE: &str = "https://github.com/anistark/wasmhub/releases/latest/download";
const JSDELIVR_BASE: &str = "https://cdn.jsdelivr.net/gh/anistark/wasmhub@latest";

const DEFAULT_MAX_RETRIES: u32 = 3;
const DEFAULT_INITIAL_BACKOFF_MS: u64 = 500;
const DEFAULT_MAX_BACKOFF_MS: u64 = 30_000;

#[derive(Debug, Clone)]
pub enum CdnSource {
    GitHubReleases,
    JsDelivr,
}

impl CdnSource {
    fn base_url(&self) -> &'static str {
        match self {
            CdnSource::GitHubReleases => GITHUB_RELEASES_BASE,
            CdnSource::JsDelivr => JSDELIVR_BASE,
        }
    }
}

pub struct RuntimeLoader {
    cache: CacheManager,
    client: Client,
    cdn_sources: Vec<CdnSource>,
    max_retries: u32,
    initial_backoff_ms: u64,
    max_backoff_ms: u64,
    #[cfg(feature = "progress")]
    show_progress: bool,
}

impl RuntimeLoader {
    pub fn new() -> Result<Self> {
        Ok(Self {
            cache: CacheManager::new()?,
            client: Client::new(),
            cdn_sources: vec![CdnSource::GitHubReleases, CdnSource::JsDelivr],
            max_retries: DEFAULT_MAX_RETRIES,
            initial_backoff_ms: DEFAULT_INITIAL_BACKOFF_MS,
            max_backoff_ms: DEFAULT_MAX_BACKOFF_MS,
            #[cfg(feature = "progress")]
            show_progress: false,
        })
    }

    pub fn builder() -> RuntimeLoaderBuilder {
        RuntimeLoaderBuilder::default()
    }

    pub async fn get_runtime(&self, language: Language, version: &str) -> Result<Runtime> {
        if let Some(runtime) = self.cache.get(language, version) {
            return Ok(runtime);
        }

        self.download_runtime(language, version).await
    }

    pub async fn download_runtime(&self, language: Language, version: &str) -> Result<Runtime> {
        let manifest = self.fetch_runtime_manifest(language).await?;
        let version_info = manifest
            .get_version(version)
            .ok_or_else(|| Error::VersionNotFound {
                language: language.to_string(),
                version: version.to_string(),
            })?;

        let mut last_error = None;
        for source in &self.cdn_sources {
            let url = self.build_download_url(source, language, version);
            match self.download_from_url(&url).await {
                Ok(data) => {
                    let computed_hash = self.compute_hash(&data);
                    if computed_hash != version_info.sha256 {
                        return Err(Error::IntegrityCheckFailed {
                            expected: version_info.sha256.clone(),
                            actual: computed_hash,
                        });
                    }

                    return self.cache.store(language, version, &data);
                }
                Err(e) => {
                    last_error = Some(e);
                    continue;
                }
            }
        }

        Err(last_error.unwrap_or_else(|| Error::Other("All CDN sources failed".to_string())))
    }

    fn build_download_url(&self, source: &CdnSource, language: Language, version: &str) -> String {
        let filename = format!("{}-{}.wasm", language.as_str(), version);
        match source {
            CdnSource::GitHubReleases => {
                format!("{}/{}", source.base_url(), filename)
            }
            CdnSource::JsDelivr => {
                format!(
                    "{}/runtimes/{}/{}",
                    source.base_url(),
                    language.as_str(),
                    filename
                )
            }
        }
    }

    async fn download_from_url(&self, url: &str) -> Result<Vec<u8>> {
        let mut last_error = None;

        for attempt in 0..=self.max_retries {
            if attempt > 0 {
                let backoff = std::cmp::min(
                    self.initial_backoff_ms * 2u64.pow(attempt - 1),
                    self.max_backoff_ms,
                );
                tokio::time::sleep(Duration::from_millis(backoff)).await;
            }

            match self.attempt_download(url).await {
                Ok(data) => return Ok(data),
                Err(e) => {
                    if !Self::is_retryable(&e) {
                        return Err(e);
                    }
                    last_error = Some(e);
                }
            }
        }

        Err(last_error.unwrap_or_else(|| Error::Other("Download failed after retries".to_string())))
    }

    async fn attempt_download(&self, url: &str) -> Result<Vec<u8>> {
        #[cfg(feature = "progress")]
        if self.show_progress {
            return self.download_with_progress(url).await;
        }

        let response = self.client.get(url).send().await?;
        if !response.status().is_success() {
            return Err(Error::Network(response.error_for_status().unwrap_err()));
        }

        let bytes = response.bytes().await?;
        Ok(bytes.to_vec())
    }

    fn is_retryable(error: &Error) -> bool {
        match error {
            Error::Network(e) => {
                if let Some(status) = e.status() {
                    status.is_server_error() || status == reqwest::StatusCode::TOO_MANY_REQUESTS
                } else {
                    e.is_timeout() || e.is_connect() || e.is_request()
                }
            }
            Error::Io(_) => true,
            _ => false,
        }
    }

    #[cfg(feature = "progress")]
    async fn download_with_progress(&self, url: &str) -> Result<Vec<u8>> {
        use indicatif::{ProgressBar, ProgressStyle};

        let response = self.client.get(url).send().await?;
        if !response.status().is_success() {
            return Err(Error::Network(response.error_for_status().unwrap_err()));
        }

        let total_size = response.content_length().unwrap_or(0);
        let pb = ProgressBar::new(total_size);
        pb.set_style(
            ProgressStyle::default_bar()
                .template("{msg}\n{spinner:.green} [{elapsed_precise}] [{wide_bar:.cyan/blue}] {bytes}/{total_bytes} ({eta})")
                .unwrap()
                .progress_chars("#>-"),
        );
        pb.set_message(format!("Downloading {url}"));

        let mut downloaded: u64 = 0;
        let mut stream = response.bytes_stream();
        let mut data = Vec::new();

        while let Some(chunk) = stream.next().await {
            let chunk = chunk?;
            data.extend_from_slice(&chunk);
            downloaded += chunk.len() as u64;
            pb.set_position(downloaded);
        }

        pb.finish_with_message("Download complete");
        Ok(data)
    }

    fn compute_hash(&self, data: &[u8]) -> String {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(data);
        format!("{:x}", hasher.finalize())
    }

    pub async fn list_available(&self) -> Result<GlobalManifest> {
        self.fetch_global_manifest().await
    }

    pub async fn get_latest_version(&self, language: Language) -> Result<String> {
        let manifest = self.fetch_global_manifest().await?;
        let runtime_info =
            manifest
                .get_language(language.as_str())
                .ok_or_else(|| Error::ManifestNotFound {
                    language: language.to_string(),
                })?;
        Ok(runtime_info.latest.clone())
    }

    pub fn clear_cache(&self, language: Language, version: &str) -> Result<()> {
        self.cache.clear(language, version)
    }

    pub fn clear_all_cache(&self) -> Result<()> {
        self.cache.clear_all()
    }

    pub fn list_cached(&self) -> Result<Vec<Runtime>> {
        self.cache.list()
    }

    async fn fetch_global_manifest(&self) -> Result<GlobalManifest> {
        let mut last_error = None;
        for source in &self.cdn_sources {
            let url = format!("{}/manifest.json", source.base_url());

            match self.fetch_json(&url).await {
                Ok(manifest) => return Ok(manifest),
                Err(e) => {
                    last_error = Some(e);
                    continue;
                }
            }
        }

        Err(last_error.unwrap_or_else(|| Error::Other("Failed to fetch manifest".to_string())))
    }

    pub async fn fetch_runtime_manifest(&self, language: Language) -> Result<RuntimeManifest> {
        let mut last_error = None;
        for source in &self.cdn_sources {
            let url = match source {
                CdnSource::GitHubReleases => {
                    format!("{}/{}-manifest.json", source.base_url(), language.as_str())
                }
                CdnSource::JsDelivr => {
                    format!(
                        "{}/runtimes/{}/manifest.json",
                        source.base_url(),
                        language.as_str()
                    )
                }
            };

            match self.fetch_json(&url).await {
                Ok(manifest) => return Ok(manifest),
                Err(e) => {
                    last_error = Some(e);
                    continue;
                }
            }
        }

        Err(last_error.unwrap_or_else(|| Error::ManifestNotFound {
            language: language.to_string(),
        }))
    }

    async fn fetch_json<T: serde::de::DeserializeOwned>(&self, url: &str) -> Result<T> {
        let response = self.client.get(url).send().await?;
        if !response.status().is_success() {
            return Err(Error::Network(response.error_for_status().unwrap_err()));
        }
        let json = response.json().await?;
        Ok(json)
    }
}

impl Default for RuntimeLoader {
    fn default() -> Self {
        Self::new().expect("Failed to create RuntimeLoader")
    }
}

#[derive(Default)]
pub struct RuntimeLoaderBuilder {
    cache_dir: Option<PathBuf>,
    cdn_sources: Option<Vec<CdnSource>>,
    max_retries: Option<u32>,
    initial_backoff_ms: Option<u64>,
    max_backoff_ms: Option<u64>,
    #[cfg(feature = "progress")]
    show_progress: bool,
}

impl RuntimeLoaderBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn cache_dir(mut self, path: PathBuf) -> Self {
        self.cache_dir = Some(path);
        self
    }

    pub fn cdn_sources(mut self, sources: Vec<CdnSource>) -> Self {
        self.cdn_sources = Some(sources);
        self
    }

    pub fn max_retries(mut self, retries: u32) -> Self {
        self.max_retries = Some(retries);
        self
    }

    pub fn initial_backoff_ms(mut self, ms: u64) -> Self {
        self.initial_backoff_ms = Some(ms);
        self
    }

    pub fn max_backoff_ms(mut self, ms: u64) -> Self {
        self.max_backoff_ms = Some(ms);
        self
    }

    #[cfg(feature = "progress")]
    pub fn show_progress(mut self, show: bool) -> Self {
        self.show_progress = show;
        self
    }

    pub fn build(self) -> Result<RuntimeLoader> {
        let cache = if let Some(cache_dir) = self.cache_dir {
            CacheManager::with_cache_dir(cache_dir)
        } else {
            CacheManager::new()?
        };

        Ok(RuntimeLoader {
            cache,
            client: Client::new(),
            cdn_sources: self
                .cdn_sources
                .unwrap_or_else(|| vec![CdnSource::GitHubReleases, CdnSource::JsDelivr]),
            max_retries: self.max_retries.unwrap_or(DEFAULT_MAX_RETRIES),
            initial_backoff_ms: self
                .initial_backoff_ms
                .unwrap_or(DEFAULT_INITIAL_BACKOFF_MS),
            max_backoff_ms: self.max_backoff_ms.unwrap_or(DEFAULT_MAX_BACKOFF_MS),
            #[cfg(feature = "progress")]
            show_progress: self.show_progress,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cdn_source_base_url() {
        assert_eq!(
            CdnSource::GitHubReleases.base_url(),
            "https://github.com/anistark/wasmhub/releases/latest/download"
        );
        assert_eq!(
            CdnSource::JsDelivr.base_url(),
            "https://cdn.jsdelivr.net/gh/anistark/wasmhub@latest"
        );
    }

    #[test]
    fn test_build_download_url() {
        let loader = RuntimeLoader::new().unwrap();

        let url = loader.build_download_url(&CdnSource::GitHubReleases, Language::Python, "3.11.7");
        assert!(url.contains("releases/latest/download"));
        assert!(url.contains("python-3.11.7.wasm"));

        let url = loader.build_download_url(&CdnSource::JsDelivr, Language::Python, "3.11.7");
        assert!(url.contains("cdn.jsdelivr.net"));
        assert!(url.contains("runtimes/python/python-3.11.7.wasm"));
    }

    #[test]
    fn test_compute_hash() {
        let loader = RuntimeLoader::new().unwrap();
        let data = b"test data";
        let hash = loader.compute_hash(data);
        assert_eq!(hash.len(), 64);
    }

    #[test]
    fn test_builder() {
        let loader = RuntimeLoader::builder()
            .cdn_sources(vec![CdnSource::GitHubReleases])
            .build()
            .unwrap();

        assert_eq!(loader.cdn_sources.len(), 1);
    }

    #[test]
    fn test_builder_with_retry_config() {
        let loader = RuntimeLoader::builder()
            .max_retries(5)
            .initial_backoff_ms(1000)
            .max_backoff_ms(60_000)
            .build()
            .unwrap();

        assert_eq!(loader.max_retries, 5);
        assert_eq!(loader.initial_backoff_ms, 1000);
        assert_eq!(loader.max_backoff_ms, 60_000);
    }

    #[test]
    fn test_is_retryable() {
        let io_err = Error::Io(std::io::Error::new(std::io::ErrorKind::TimedOut, "timeout"));
        assert!(RuntimeLoader::is_retryable(&io_err));

        let integrity_err = Error::IntegrityCheckFailed {
            expected: "a".to_string(),
            actual: "b".to_string(),
        };
        assert!(!RuntimeLoader::is_retryable(&integrity_err));
    }

    #[test]
    fn test_builder_with_cache_dir() {
        use tempfile::TempDir;
        let temp_dir = TempDir::new().unwrap();

        let loader = RuntimeLoader::builder()
            .cache_dir(temp_dir.path().to_path_buf())
            .build()
            .unwrap();

        assert!(loader
            .cache
            .get_path(Language::Python, "3.11.7")
            .starts_with(temp_dir.path()));
    }
}
