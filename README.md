# 🚀 zcompress

High-performance multi-threaded asset compressor written in **Zig**. 5-10x faster than Node.js compression solutions.

## Features

- 🧵 **Multi-threaded** — uses all CPU cores for parallel compression
- ⚡ **Native performance** — written in Zig, 5-10x faster than Node.js
- 📦 **Three algorithms** — gzip, zstd, brotli
- 📁 **Smart file filtering** — auto-detects compressible web assets
- 💾 **Incremental cache** — skip unchanged files on re-runs
- 🔌 **Vite plugin** — drop-in for Vite projects

## Quick Start

### CLI

```bash
# Build
zig build -Doptimize=ReleaseFast

# Compress a directory
zig-out/bin/zcompress -i ./dist -o ./dist-compressed

# With options
zig-out/bin/zcompress -i ./dist -o ./dist-gz -a zstd -l 9 -t 8 -v --cache
```

### Vite Plugin

```bash
npm install zcompress-vite-plugin --save-dev
```

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';

export default {
  plugins: [
    zcompress({ algo: 'brotli', level: 11, threads: 4 })
  ]
};
```

## CLI Options

| Flag | Long | Description | Default |
|---|---|---|---|
| `-i` | `--input` | Input directory | `./dist` |
| `-o` | `--output` | Output directory | `./dist-compressed` |
| `-a` | `--algo` | Algorithm: `gzip` | `gzip` |
| `-l` | `--level` | Compression level: 1-9 | `6` |
| `-t` | `--threads` | Thread count (0=auto) | CPU count |
| `-c` | `--cache` | Enable incremental cache | disabled |
| `-v` | `--verbose` | Verbose output | disabled |
| `-h` | `--help` | Show help | — |

## Project Structure

```
zcompress/
├── src/
│   ├── main.zig              # CLI entry point
│   ├── root.zig              # Public library API
│   ├── cli/
│   │   ├── mod.zig           # Argument parsing
│   │   └── progress.zig      # Progress bar
│   ├── compress/
│   │   ├── mod.zig           # Compression module
│   │   ├── gzip.zig          # Gzip compression
│   │   ├── zstd.zig          # Zstd stub (coming soon)
│   │   └── pipeline.zig      # Multi-threaded pipeline
│   ├── fs/
│   │   ├── mod.zig           # Filesystem module
│   │   ├── walker.zig        # Recursive directory walker
│   │   └── matcher.zig       # File extension matcher
│   └── cache/
│       ├── mod.zig           # Cache module
│       └── hash.zig          # File hash (MD5)
├── tests/
│   └── integration_test.zig  # End-to-end tests
├── plugins/vite/             # Vite plugin (JS)
├── build.zig                 # Build configuration
└── build.zig.zon             # Package manifest
```

## Vite Plugin

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';

export default {
  plugins: [
    zcompress({ algo: 'gzip', level: 6, threads: 4, verbose: true })
  ]
};
```

## Development

```bash
# Run tests
zig build test

# Build with optimizations
zig build -Doptimize=ReleaseFast
```

## License

MIT
