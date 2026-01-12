use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use wasmhub::{CacheManager, Language, RuntimeLoader};

#[derive(Parser)]
#[command(name = "wasmhub")]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Download a runtime (or get from cache)
    Get {
        /// Language (nodejs, python, ruby, php, go, rust)
        language: String,

        /// Version (use 'latest' or 'lts' for auto-selection)
        #[arg(default_value = "latest")]
        version: String,

        /// Force re-download even if cached
        #[arg(short, long)]
        force: bool,
    },

    /// List all available runtimes
    List {
        /// Language filter (optional)
        language: Option<String>,
    },

    /// Show detailed information about a runtime
    Info {
        /// Language (nodejs, python, ruby, php, go, rust)
        language: String,

        /// Version (optional, shows info for specific version)
        version: Option<String>,
    },

    /// Manage cache
    Cache {
        #[command(subcommand)]
        action: CacheAction,
    },
}

#[derive(Subcommand)]
enum CacheAction {
    /// Show cache location and contents
    Show,

    /// Clear cache for a specific runtime
    Clear {
        /// Language (nodejs, python, ruby, php, go, rust)
        language: String,

        /// Version
        version: String,
    },

    /// Clear all cached runtimes
    ClearAll {
        /// Skip confirmation prompt
        #[arg(short, long)]
        yes: bool,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Get {
            language,
            version,
            force,
        } => handle_get(language, version, force).await,
        Commands::List { language } => handle_list(language).await,
        Commands::Info { language, version } => handle_info(language, version).await,
        Commands::Cache { action } => handle_cache(action),
    }
}

async fn handle_get(language_str: String, version: String, force: bool) -> Result<()> {
    let language: Language = language_str
        .parse()
        .map_err(|e: String| anyhow::anyhow!(e))?;

    println!(
        "{} {} runtime (version: {})...",
        "Fetching".cyan().bold(),
        language,
        version
    );

    let loader = RuntimeLoader::builder().show_progress(true).build()?;

    if force {
        let cache = CacheManager::new()?;
        if cache.get(language, &version).is_some() {
            cache.clear(language, &version)?;
            println!("{} cache", "Cleared".yellow());
        }
    }

    let actual_version = if version == "latest" {
        loader.get_latest_version(language).await?
    } else if version == "lts" {
        let manifest = loader.list_available().await?;
        let runtime_info = manifest
            .languages
            .get(language.as_str())
            .context(format!("No manifest found for {language}"))?;
        runtime_info
            .lts
            .clone()
            .context(format!("No LTS version available for {language}"))?
    } else {
        version.clone()
    };

    let runtime = loader.get_runtime(language, &actual_version).await?;

    println!("\n{}", "Success!".green().bold());
    println!("  {}: {}", "Language".bold(), runtime.language);
    println!("  {}: {}", "Version".bold(), runtime.version);
    println!("  {}: {}", "Path".bold(), runtime.path.display());
    println!(
        "  {}: {} MB",
        "Size".bold(),
        runtime.size as f64 / 1_048_576.0
    );
    println!("  {}: {}", "SHA256".bold(), runtime.sha256);

    Ok(())
}

async fn handle_list(language_filter: Option<String>) -> Result<()> {
    println!("{} available runtimes...\n", "Fetching".cyan().bold());

    let loader = RuntimeLoader::new()?;
    let manifest = loader.list_available().await?;

    let languages: Vec<Language> = if let Some(lang_str) = language_filter {
        let lang: Language = lang_str.parse().map_err(|e: String| anyhow::anyhow!(e))?;
        vec![lang]
    } else {
        Language::all().to_vec()
    };

    for language in languages {
        if let Some(info) = manifest.languages.get(language.as_str()) {
            println!("{}", format!("{language}:").green().bold());
            println!("  {}: {}", "Latest".bold(), info.latest);
            if let Some(lts) = &info.lts {
                println!("  {}: {}", "LTS".bold(), lts);
            }
            println!(
                "  {}: {}",
                "Versions".bold(),
                info.versions.len().to_string().cyan()
            );

            if !info.versions.is_empty() {
                let versions_str = info
                    .versions
                    .iter()
                    .take(5)
                    .map(|v| v.as_str())
                    .collect::<Vec<_>>()
                    .join(", ");
                let more = if info.versions.len() > 5 {
                    format!(" and {} more", info.versions.len() - 5)
                } else {
                    String::new()
                };
                println!("  {}: {}{}", "Available".bold(), versions_str, more);
            }

            println!("  {}: {}", "Source".bold(), info.source.dimmed());
            println!();
        }
    }

    Ok(())
}

async fn handle_info(language_str: String, version: Option<String>) -> Result<()> {
    let language: Language = language_str
        .parse()
        .map_err(|e: String| anyhow::anyhow!(e))?;

    let loader = RuntimeLoader::new()?;
    let manifest = loader.list_available().await?;

    let info = manifest
        .languages
        .get(language.as_str())
        .context(format!("No information found for {language}"))?;

    println!("\n{} {}\n", "Runtime Info:".cyan().bold(), language);
    println!("  {}: {}", "Latest".bold(), info.latest);
    if let Some(lts) = &info.lts {
        println!("  {}: {}", "LTS".bold(), lts);
    }
    println!("  {}: {}", "Source".bold(), &info.source);
    println!("  {}: {}", "License".bold(), &info.license);

    if let Some(ver) = version {
        println!("\n{} {}:\n", "Version Details for".cyan().bold(), ver);

        let runtime_manifest = loader
            .fetch_runtime_manifest(language)
            .await
            .context(format!("Failed to fetch manifest for {language}"))?;

        if let Some(ver_info) = runtime_manifest.versions.get(&ver) {
            println!("  {}: {}", "File".bold(), ver_info.file);
            println!(
                "  {}: {} MB",
                "Size".bold(),
                ver_info.size as f64 / 1_048_576.0
            );
            println!("  {}: {}", "SHA256".bold(), ver_info.sha256);
            println!("  {}: {}", "Released".bold(), &ver_info.released);
            println!("  {}: {}", "WASI".bold(), ver_info.wasi);
            if !ver_info.features.is_empty() {
                println!("  {}: {}", "Features".bold(), ver_info.features.join(", "));
            }
            println!("  {}: {}", "URL".bold(), ver_info.url.dimmed());
        } else {
            println!("  {}: Version {} not found", "Error".red(), ver);
        }
    } else {
        println!(
            "\n{} ({}):\n",
            "Available Versions".cyan().bold(),
            info.versions.len()
        );
        for version in &info.versions {
            println!("  - {version}");
        }
    }

    Ok(())
}

fn handle_cache(action: CacheAction) -> Result<()> {
    let cache = CacheManager::new()?;

    match action {
        CacheAction::Show => {
            let cache_dir = CacheManager::default_cache_dir()?;
            println!("\n{}\n", "Cache Information:".cyan().bold());
            println!("  {}: {}", "Location".bold(), cache_dir.display());

            let runtimes = cache.list()?;
            if runtimes.is_empty() {
                println!("\n  {}", "No cached runtimes".yellow());
            } else {
                println!("\n  {}:\n", "Cached Runtimes".bold());
                let mut total_size = 0u64;

                for runtime in &runtimes {
                    total_size += runtime.size;
                    println!(
                        "    {} {} {} {}",
                        "•".green(),
                        runtime.language.to_string().cyan(),
                        runtime.version.yellow(),
                        format!("({:.2} MB)", runtime.size as f64 / 1_048_576.0).dimmed()
                    );
                }

                println!(
                    "\n  {}: {} runtimes, {:.2} MB total",
                    "Total".bold(),
                    runtimes.len(),
                    total_size as f64 / 1_048_576.0
                );
            }

            println!();
            Ok(())
        }

        CacheAction::Clear { language, version } => {
            let lang: Language = language.parse().map_err(|e: String| anyhow::anyhow!(e))?;

            cache.clear(lang, &version)?;
            println!(
                "{} cache for {} {}",
                "Cleared".green().bold(),
                lang,
                version
            );
            Ok(())
        }

        CacheAction::ClearAll { yes } => {
            if !yes {
                print!("Are you sure you want to clear all cached runtimes? (y/N): ");
                use std::io::Write;
                std::io::stdout().flush()?;

                let mut response = String::new();
                std::io::stdin().read_line(&mut response)?;

                if !response.trim().eq_ignore_ascii_case("y") {
                    println!("{}", "Cancelled".yellow());
                    return Ok(());
                }
            }

            cache.clear_all()?;
            println!("{} all cached runtimes", "Cleared".green().bold());
            Ok(())
        }
    }
}
