use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GlobalManifest {
    pub version: String,
    #[serde(default)]
    pub languages: HashMap<String, RuntimeInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RuntimeInfo {
    pub latest: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lts: Option<String>,
    pub versions: Vec<String>,
    pub source: String,
    pub license: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RuntimeManifest {
    pub language: String,
    pub versions: HashMap<String, RuntimeVersion>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RuntimeVersion {
    pub file: String,
    pub size: u64,
    pub sha256: String,
    pub released: String,
    #[serde(default)]
    pub wasi: String,
    #[serde(default)]
    pub features: Vec<String>,
    #[serde(default)]
    pub url: String,
}

impl GlobalManifest {
    pub fn new(version: String) -> Self {
        Self {
            version,
            languages: HashMap::new(),
        }
    }

    pub fn add_language(&mut self, name: String, info: RuntimeInfo) {
        self.languages.insert(name, info);
    }

    pub fn get_language(&self, name: &str) -> Option<&RuntimeInfo> {
        self.languages.get(name)
    }
}

impl RuntimeInfo {
    pub fn new(latest: String, source: String, license: String) -> Self {
        Self {
            latest,
            lts: None,
            versions: Vec::new(),
            source,
            license,
        }
    }

    pub fn with_lts(mut self, lts: String) -> Self {
        self.lts = Some(lts);
        self
    }

    pub fn add_version(&mut self, version: String) {
        if !self.versions.contains(&version) {
            self.versions.push(version);
        }
    }
}

impl RuntimeManifest {
    pub fn new(language: String) -> Self {
        Self {
            language,
            versions: HashMap::new(),
        }
    }

    pub fn add_version(&mut self, version: String, info: RuntimeVersion) {
        self.versions.insert(version, info);
    }

    pub fn get_version(&self, version: &str) -> Option<&RuntimeVersion> {
        self.versions.get(version)
    }
}

impl RuntimeVersion {
    pub fn new(file: String, size: u64, sha256: String, released: String, url: String) -> Self {
        Self {
            file,
            size,
            sha256,
            released,
            wasi: String::new(),
            features: Vec::new(),
            url,
        }
    }

    pub fn with_wasi(mut self, wasi: String) -> Self {
        self.wasi = wasi;
        self
    }

    pub fn add_feature(&mut self, feature: String) {
        if !self.features.contains(&feature) {
            self.features.push(feature);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_global_manifest() {
        let mut manifest = GlobalManifest::new("1.0.0".to_string());
        assert_eq!(manifest.version, "1.0.0");
        assert_eq!(manifest.languages.len(), 0);

        let runtime_info = RuntimeInfo::new(
            "3.11.7".to_string(),
            "https://github.com/pyodide/pyodide".to_string(),
            "MIT".to_string(),
        );
        manifest.add_language("python".to_string(), runtime_info);
        assert_eq!(manifest.languages.len(), 1);
        assert!(manifest.get_language("python").is_some());
    }

    #[test]
    fn test_runtime_info() {
        let mut info = RuntimeInfo::new(
            "20.2.0".to_string(),
            "https://nodejs.org".to_string(),
            "MIT".to_string(),
        );
        assert_eq!(info.latest, "20.2.0");
        assert!(info.lts.is_none());

        info = info.with_lts("18.19.0".to_string());
        assert_eq!(info.lts, Some("18.19.0".to_string()));

        info.add_version("20.2.0".to_string());
        info.add_version("18.19.0".to_string());
        assert_eq!(info.versions.len(), 2);

        info.add_version("20.2.0".to_string());
        assert_eq!(info.versions.len(), 2);
    }

    #[test]
    fn test_runtime_manifest() {
        let mut manifest = RuntimeManifest::new("python".to_string());
        assert_eq!(manifest.language, "python");
        assert_eq!(manifest.versions.len(), 0);

        let version = RuntimeVersion::new(
            "python-3.11.7.wasm".to_string(),
            1024,
            "abc123".to_string(),
            "2024-01-01".to_string(),
            "https://example.com/python-3.11.7.wasm".to_string(),
        );
        manifest.add_version("3.11.7".to_string(), version);
        assert_eq!(manifest.versions.len(), 1);
        assert!(manifest.get_version("3.11.7").is_some());
    }

    #[test]
    fn test_runtime_version() {
        let mut version = RuntimeVersion::new(
            "python-3.11.7.wasm".to_string(),
            1024,
            "abc123".to_string(),
            "2024-01-01".to_string(),
            "https://example.com/python-3.11.7.wasm".to_string(),
        );
        assert_eq!(version.file, "python-3.11.7.wasm");
        assert_eq!(version.size, 1024);
        assert!(version.wasi.is_empty());

        version = version.with_wasi("wasip1".to_string());
        assert_eq!(version.wasi, "wasip1");

        version.add_feature("async".to_string());
        version.add_feature("filesystem".to_string());
        assert_eq!(version.features.len(), 2);

        version.add_feature("async".to_string());
        assert_eq!(version.features.len(), 2);
    }

    #[test]
    fn test_manifest_serialization() {
        let manifest = GlobalManifest {
            version: "1.0.0".to_string(),
            languages: {
                let mut map = HashMap::new();
                map.insert(
                    "python".to_string(),
                    RuntimeInfo {
                        latest: "3.11.7".to_string(),
                        lts: None,
                        versions: vec!["3.11.7".to_string()],
                        source: "https://github.com/pyodide/pyodide".to_string(),
                        license: "MIT".to_string(),
                    },
                );
                map
            },
        };

        let json = serde_json::to_string(&manifest).unwrap();
        let parsed: GlobalManifest = serde_json::from_str(&json).unwrap();
        assert_eq!(manifest, parsed);
    }
}
