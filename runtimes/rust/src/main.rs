use std::env;
use std::fs;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        print_usage();
        return;
    }

    match args[1].as_str() {
        "version" => print_version(),
        "eval" => {
            if args.len() < 3 {
                eprintln!("Error: eval requires an expression");
                process::exit(1);
            }
            eval(&args[2]);
        }
        "env" => print_env(),
        "echo" => {
            for (i, arg) in args[2..].iter().enumerate() {
                if i > 0 {
                    print!(" ");
                }
                print!("{}", arg);
            }
            println!();
        }
        "cat" => {
            if args.len() < 3 {
                eprintln!("Error: cat requires a filename");
                process::exit(1);
            }
            cat_file(&args[2]);
        }
        "ls" => {
            let path = if args.len() > 2 { &args[2] } else { "." };
            list_dir(path);
        }
        "write" => {
            if args.len() < 4 {
                eprintln!("Error: write requires filename and content");
                process::exit(1);
            }
            write_file(&args[2], &args[3]);
        }
        _ => {
            eprintln!("Unknown command: {}", args[1]);
            print_usage();
            process::exit(1);
        }
    }
}

fn print_usage() {
    println!("WasmHub Rust Runtime");
    println!();
    println!("Usage: rust-runtime <command> [args...]");
    println!();
    println!("Commands:");
    println!("  version      Print runtime version info");
    println!("  eval <expr>  Evaluate a simple expression");
    println!("  env          Print environment variables");
    println!("  echo [args]  Print arguments to stdout");
    println!("  cat <file>   Print file contents");
    println!("  ls [path]    List directory contents");
    println!("  write <file> <content>  Write content to file");
}

fn print_version() {
    println!("WasmHub Rust Runtime");
    println!("Rust Version: 1.82.0");
    println!("Target: WASI Preview 1 (wasm32-wasip1)");
    println!("Features: filesystem, env, args, stdio, full std library");
}

fn eval(expr: &str) {
    println!("Evaluating: {}", expr);
    println!("Note: Full eval requires a Rust interpreter");
    println!("Expression length: {} characters", expr.len());
}

fn print_env() {
    for (key, value) in env::vars() {
        println!("{}={}", key, value);
    }
}

fn cat_file(path: &str) {
    match fs::read_to_string(path) {
        Ok(contents) => print!("{}", contents),
        Err(e) => {
            eprintln!("Error reading {}: {}", path, e);
            process::exit(1);
        }
    }
}

fn list_dir(path: &str) {
    match fs::read_dir(path) {
        Ok(entries) => {
            for entry in entries {
                match entry {
                    Ok(entry) => {
                        let metadata = entry.metadata();
                        let name = entry.file_name();
                        let name_str = name.to_string_lossy();

                        match metadata {
                            Ok(meta) => {
                                let type_char = if meta.is_dir() { "d" } else { "-" };
                                println!("{} {:>8} {}", type_char, meta.len(), name_str);
                            }
                            Err(_) => println!("- {:>8} {}", 0, name_str),
                        }
                    }
                    Err(e) => eprintln!("Error reading entry: {}", e),
                }
            }
        }
        Err(e) => {
            eprintln!("Error reading directory {}: {}", path, e);
            process::exit(1);
        }
    }
}

fn write_file(path: &str, content: &str) {
    match fs::write(path, content) {
        Ok(_) => println!("Wrote {} bytes to {}", content.len(), path),
        Err(e) => {
            eprintln!("Error writing {}: {}", path, e);
            process::exit(1);
        }
    }
}
