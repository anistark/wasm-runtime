package main

import (
	"fmt"
	"os"
)

func main() {
	args := os.Args
	if len(args) < 2 {
		printUsage()
		return
	}

	switch args[1] {
	case "version":
		printVersion()
	case "eval":
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Error: eval requires an expression")
			os.Exit(1)
		}
		eval(args[2])
	case "env":
		printEnv()
	case "echo":
		if len(args) > 2 {
			for i, arg := range args[2:] {
				if i > 0 {
					fmt.Print(" ")
				}
				fmt.Print(arg)
			}
		}
		fmt.Println()
	case "cat":
		if len(args) < 3 {
			fmt.Fprintln(os.Stderr, "Error: cat requires a filename")
			os.Exit(1)
		}
		catFile(args[2])
	case "ls":
		path := "."
		if len(args) > 2 {
			path = args[2]
		}
		listDir(path)
	case "write":
		if len(args) < 4 {
			fmt.Fprintln(os.Stderr, "Error: write requires filename and content")
			os.Exit(1)
		}
		writeFile(args[2], args[3])
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", args[1])
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("WasmHub Go Runtime")
	fmt.Println()
	fmt.Println("Usage: go-runtime <command> [args...]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  version      Print runtime version info")
	fmt.Println("  eval <expr>  Evaluate a simple expression")
	fmt.Println("  env          Print environment variables")
	fmt.Println("  echo [args]  Print arguments to stdout")
	fmt.Println("  cat <file>   Print file contents")
	fmt.Println("  ls [path]    List directory contents")
	fmt.Println("  write <file> <content>  Write content to file")
}

func printVersion() {
	fmt.Println("WasmHub Go Runtime")
	fmt.Println("Go Version: 1.23 (TinyGo)")
	fmt.Println("Target: WASI Preview 1")
	fmt.Println("Features: filesystem, env, args, stdio")
}

func eval(expr string) {
	fmt.Printf("Evaluating: %s\n", expr)
	fmt.Println("Note: Full eval requires a Go interpreter")
	fmt.Printf("Expression length: %d characters\n", len(expr))
}

func printEnv() {
	for _, env := range os.Environ() {
		fmt.Println(env)
	}
}

func catFile(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading %s: %v\n", path, err)
		os.Exit(1)
	}
	fmt.Print(string(data))
}

func listDir(path string) {
	entries, err := os.ReadDir(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading directory %s: %v\n", path, err)
		os.Exit(1)
	}
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil {
			fmt.Println(entry.Name())
			continue
		}
		typeChar := "-"
		if entry.IsDir() {
			typeChar = "d"
		}
		fmt.Printf("%s %8d %s\n", typeChar, info.Size(), entry.Name())
	}
}

func writeFile(path, content string) {
	err := os.WriteFile(path, []byte(content), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error writing %s: %v\n", path, err)
		os.Exit(1)
	}
	fmt.Printf("Wrote %d bytes to %s\n", len(content), path)
}
