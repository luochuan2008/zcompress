# zcompress Vite Plugin

High-performance multi-threaded asset compression for Vite production builds, powered by [zcompress](https://github.com/luochuan2008/zcompress) (Zig).

## Features

- 🧵 **Multi-threaded** — all CPU cores, not just one
- ⚡ **5-10x faster** than Node.js compression plugins
- 📦 **gzip**, **zstd**, **brotli** — all three algorithms
- 💾 **Incremental cache** — skip unchanged files

## Quick Start

```bash
npm install zcompress-vite-plugin --save-dev
```

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';

export default {
  plugins: [
    zcompress({
      algo: 'gzip',    // 'gzip' | 'zstd' | 'brotli'
      level: 6,        // 1-9
      threads: 4,      // 0 = auto
      cache: true,     // skip unchanged files
    })
  ]
};
```

After `vite build`, you'll get a `dist-compressed/` folder with `.gz` (or `.zst`/`.br`) files.

## How It Works

The plugin ships a JS wrapper. On `npm install`, it downloads the prebuilt Zig binary for your platform from GitHub Releases. If the download fails (air-gapped, unsupported arch), it falls back to looking for `zcompress` in your PATH.

```bash
# Manual install (if auto-download fails)
brew install zcompress           # macOS
zig build install                # from source
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `algo` | `'gzip' \| 'zstd' \| 'brotli'` | `'gzip'` | Compression algorithm |
| `level` | `number` | `6` | Compression level (1-9) |
| `threads` | `number` | `0` | Thread count (0 = auto) |
| `verbose` | `boolean` | `false` | Verbose output |
| `cache` | `boolean` | `false` | Skip unchanged files |
| `include` | `string[]` | `[]` | Extra extensions to compress |
| `exclude` | `string[]` | `[]` | Extensions to skip |
| `binaryPath` | `string` | auto | Override binary path |

## License

MIT
