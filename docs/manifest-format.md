---
title: Manifest Format
description: JSON schema for per-language and global manifests
layout: libdoc_page.liquid
permalink: manifest-format/index.html
eleventyNavigation:
    key: Manifest Format
    order: 5
---

## Per-language manifest

Every runtime ships a `manifest.json` that enumerates its versions:

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

### Fields

| Field      | Type   | Notes |
|------------|--------|-------|
| `language` | string | Canonical lowercase name (e.g., `go`, `rust`) |
| `latest`   | string | Pointer to a key in `versions` |
| `versions` | map    | Keyed by version string |
| `versions[].file`     | string | Filename of the published WASM artifact |
| `versions[].size`     | number | Bytes (post-optimization) |
| `versions[].sha256`   | string | Hex-encoded SHA-256 of `file` |
| `versions[].released` | string | ISO-8601 timestamp |
| `versions[].wasi`     | string | WASI variant — `wasip1` today |
| `versions[].features` | array  | Optional WASM proposals (e.g., `bulk-memory`) |

`generate-metadata.sh` writes this file. The `latest` field auto-updates to the newest version when a build runs. Old version entries are preserved.

## Global manifest

A single `manifest.json` at the repo root aggregates every per-language manifest:

```json
{
    "version": "0.5.0",
    "build_date": "2026-02-15T14:00:00Z",
    "languages": {
        "go": {
            "latest": "1.23",
            "versions": ["1.23"],
            "source": "https://go.dev/",
            "license": "BSD-3-Clause"
        },
        "rust": {
            "latest": "1.82",
            "versions": ["1.82"],
            "source": "https://www.rust-lang.org/",
            "license": "MIT/Apache-2.0"
        }
    }
}
```

The `source` and `license` fields come from `scripts/generate-global-manifest.sh`. The aggregator runs after every build; it never edits per-language files.

## Where they live

- **Repo:** `runtimes/<lang>/manifest.json` (per-language) and `manifest.json` (global) are committed
- **Releases:** Both ship as GitHub Release assets — per-language manifests are renamed to `<lang>-manifest.json` to keep the assets directory flat
