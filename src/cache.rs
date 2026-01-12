use crate::error::{Error, Result};
use crate::runtime::{Language, Runtime};
use sha2::{Digest, Sha256};
use std::fs;
use std::io::Read;
use std::path::PathBuf;

pub struct CacheManager {
    cache_dir: PathBuf,
}

impl CacheManager {
    pub fn new() -> Result<Self> {
        let cache_dir = Self::default_cache_dir()?;
        Ok(Self { cache_dir })
    }

    pub fn with_cache_dir(cache_dir: PathBuf) -> Self {
        Self { cache_dir }
    }

    pub fn default_cache_dir() -> Result<PathBuf> {
        let cache_dir = dirs::cache_dir()
            .ok_or_else(|| Error::Other("Could not determine cache directory".to_string()))?
            .join("wasmhub");
        Ok(cache_dir)
    }

    pub fn get_path(&self, language: Language, version: &str) -> PathBuf {
        self.cache_dir
            .join(language.as_str())
            .join(format!("{version}.wasm"))
    }

    pub fn get(&self, language: Language, version: &str) -> Option<Runtime> {
        let path = self.get_path(language, version);
        if !path.exists() {
            return None;
        }

        let metadata = fs::metadata(&path).ok()?;
        let size = metadata.len();

        let sha256 = Self::compute_sha256(&path).ok()?;

        Some(Runtime::new(
            language,
            version.to_string(),
            path,
            size,
            sha256,
        ))
    }

    pub fn store(&self, language: Language, version: &str, data: &[u8]) -> Result<Runtime> {
        let path = self.get_path(language, version);

        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }

        fs::write(&path, data)?;

        let size = data.len() as u64;
        let sha256 = Self::compute_sha256(&path)?;

        Ok(Runtime::new(
            language,
            version.to_string(),
            path,
            size,
            sha256,
        ))
    }

    pub fn clear(&self, language: Language, version: &str) -> Result<()> {
        let path = self.get_path(language, version);
        if path.exists() {
            fs::remove_file(path)?;
        }
        Ok(())
    }

    pub fn clear_all(&self) -> Result<()> {
        if self.cache_dir.exists() {
            fs::remove_dir_all(&self.cache_dir)?;
        }
        Ok(())
    }

    pub fn list(&self) -> Result<Vec<Runtime>> {
        let mut runtimes = Vec::new();

        if !self.cache_dir.exists() {
            return Ok(runtimes);
        }

        for language in Language::all() {
            let lang_dir = self.cache_dir.join(language.as_str());
            if !lang_dir.exists() {
                continue;
            }

            for entry in fs::read_dir(&lang_dir)? {
                let entry = entry?;
                let path = entry.path();

                if !path.is_file() || path.extension().and_then(|s| s.to_str()) != Some("wasm") {
                    continue;
                }

                if let Some(version) = path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .map(|s| s.to_string())
                {
                    if let Some(runtime) = self.get(*language, &version) {
                        runtimes.push(runtime);
                    }
                }
            }
        }

        Ok(runtimes)
    }

    pub fn compute_sha256(path: &PathBuf) -> Result<String> {
        let mut file = fs::File::open(path)?;
        let mut hasher = Sha256::new();
        let mut buffer = [0; 8192];

        loop {
            let n = file.read(&mut buffer)?;
            if n == 0 {
                break;
            }
            hasher.update(&buffer[..n]);
        }

        let hash = hasher.finalize();
        Ok(format!("{hash:x}"))
    }

    pub fn verify_integrity(&self, runtime: &Runtime, expected_sha256: &str) -> Result<()> {
        let actual_sha256 = Self::compute_sha256(&runtime.path)?;
        if actual_sha256 != expected_sha256 {
            return Err(Error::IntegrityCheckFailed {
                expected: expected_sha256.to_string(),
                actual: actual_sha256,
            });
        }
        Ok(())
    }
}

impl Default for CacheManager {
    fn default() -> Self {
        Self::new().expect("Failed to create cache manager")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    fn create_test_cache() -> (CacheManager, TempDir) {
        let temp_dir = TempDir::new().unwrap();
        let cache_manager = CacheManager::with_cache_dir(temp_dir.path().to_path_buf());
        (cache_manager, temp_dir)
    }

    #[test]
    fn test_get_path() {
        let (cache, _temp) = create_test_cache();
        let path = cache.get_path(Language::Python, "3.11.7");
        assert!(path.to_string_lossy().contains("python"));
        assert!(path.to_string_lossy().contains("3.11.7.wasm"));
    }

    #[test]
    fn test_store_and_get() {
        let (cache, _temp) = create_test_cache();
        let data = b"test wasm data";
        let runtime = cache
            .store(Language::Python, "3.11.7", data)
            .expect("Failed to store");

        assert_eq!(runtime.language, Language::Python);
        assert_eq!(runtime.version, "3.11.7");
        assert_eq!(runtime.size, data.len() as u64);

        let retrieved = cache.get(Language::Python, "3.11.7");
        assert!(retrieved.is_some());
        let retrieved = retrieved.unwrap();
        assert_eq!(retrieved.version, "3.11.7");
        assert_eq!(retrieved.sha256, runtime.sha256);
    }

    #[test]
    fn test_get_nonexistent() {
        let (cache, _temp) = create_test_cache();
        let result = cache.get(Language::Python, "3.11.7");
        assert!(result.is_none());
    }

    #[test]
    fn test_clear() {
        let (cache, _temp) = create_test_cache();
        let data = b"test wasm data";
        cache
            .store(Language::Python, "3.11.7", data)
            .expect("Failed to store");

        assert!(cache.get(Language::Python, "3.11.7").is_some());

        cache
            .clear(Language::Python, "3.11.7")
            .expect("Failed to clear");
        assert!(cache.get(Language::Python, "3.11.7").is_none());
    }

    #[test]
    fn test_clear_all() {
        let (cache, _temp) = create_test_cache();
        let data = b"test wasm data";
        cache
            .store(Language::Python, "3.11.7", data)
            .expect("Failed to store");
        cache
            .store(Language::Ruby, "3.2.2", data)
            .expect("Failed to store");

        cache.clear_all().expect("Failed to clear all");

        assert!(cache.get(Language::Python, "3.11.7").is_none());
        assert!(cache.get(Language::Ruby, "3.2.2").is_none());
    }

    #[test]
    fn test_list() {
        let (cache, _temp) = create_test_cache();
        let data = b"test wasm data";

        cache
            .store(Language::Python, "3.11.7", data)
            .expect("Failed to store");
        cache
            .store(Language::Ruby, "3.2.2", data)
            .expect("Failed to store");

        let runtimes = cache.list().expect("Failed to list");
        assert_eq!(runtimes.len(), 2);

        let versions: Vec<String> = runtimes.iter().map(|r| r.version.clone()).collect();
        assert!(versions.contains(&"3.11.7".to_string()));
        assert!(versions.contains(&"3.2.2".to_string()));
    }

    #[test]
    fn test_compute_sha256() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.wasm");
        let data = b"test data for hashing";
        fs::write(&file_path, data).unwrap();

        let hash1 = CacheManager::compute_sha256(&file_path).unwrap();
        let hash2 = CacheManager::compute_sha256(&file_path).unwrap();

        assert_eq!(hash1, hash2);
        assert_eq!(hash1.len(), 64);
    }

    #[test]
    fn test_verify_integrity() {
        let (cache, _temp) = create_test_cache();
        let data = b"test wasm data";
        let runtime = cache
            .store(Language::Python, "3.11.7", data)
            .expect("Failed to store");

        let result = cache.verify_integrity(&runtime, &runtime.sha256);
        assert!(result.is_ok());

        let result = cache.verify_integrity(&runtime, "invalid_hash");
        assert!(result.is_err());
    }
}
