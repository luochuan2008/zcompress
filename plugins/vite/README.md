# zcompress-vite-plugin · 中文

Vite 生产构建资源压缩插件 — gzip / zstd / brotli，多线程并行，比 Node.js 方案快 5-10 倍。

## 安装 · Install

```bash
npm install zcompress-vite-plugin --save-dev
```

安装后会自动下载对应平台的 `zcompress` 二进制。下载失败可手动安装：

| 平台 | 命令 |
|------|------|
| macOS | `brew install zstd brotli && zig build -Doptimize=ReleaseFast` |
| Linux | `apt install libzstd-dev libbrotli-dev && zig build -Doptimize=ReleaseFast` |
| Windows | 安装 [Zig](https://ziglang.org/download/)，`choco install zstandard brotli`，然后 `zig build -Doptimize=ReleaseFast` |

## 使用

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';

export default {
  plugins: [
    zcompress({
      algo: 'gzip',    // 'gzip' | 'zstd' | 'brotli'
      level: 6,        // 压缩级别 1-9
      threads: 4,      // 线程数，0=自动
      cache: true,     // 跳过未修改文件
      verbose: true,   // 显示详细输出
    })
  ]
};
```

`vite build` 后，`dist-compressed/` 目录下就是压缩后的文件。

## 选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `algo` | `'gzip' \| 'zstd' \| 'brotli'` | `'gzip'` | 压缩算法 |
| `level` | `number` | `6` | 压缩级别 (1-9) |
| `threads` | `number` | `0` | 线程数 (0=CPU 核心数) |
| `verbose` | `boolean` | `false` | 显示详细输出 |
| `cache` | `boolean` | `false` | 跳过未修改文件 |
| `include` | `string[]` | `[]` | 额外压缩扩展名 |
| `exclude` | `string[]` | `[]` | 排除扩展名 |
| `binaryPath` | `string` | 自动 | 手动指定二进制路径 |
| `failOnError` | `boolean` | `true` | 压缩失败时让 `vite build` 失败 |

## 故障排查

### `postinstall` 下载二进制 404

如果看到类似：

```txt
https://github.com/luochuan2008/zcompress/releases/download/vX.Y.Z/zcompress-macos-arm64 → 404
```

说明 npm 版本已发布，但对应 GitHub Release 还没上传该平台二进制。

解决方式：

1. 手动安装 CLI（上面安装表）
2. 在插件里指定 `binaryPath`

```js
zcompress({
  binaryPath: '/absolute/path/to/zcompress',
})
```

也可用环境变量（不改代码）：

```bash
export ZCOMPRESS_BINARY=/absolute/path/to/zcompress
npm run build
```

默认 `failOnError: true`，失败会直接中断构建（不会静默跳过压缩）。

## License

MIT

---

# zcompress-vite-plugin · English

High-performance multi-threaded asset compression for Vite production builds. 5-10x faster than Node.js alternatives.

## Install

```bash
npm install zcompress-vite-plugin --save-dev
```

The package auto-downloads a platform binary. If that fails, install/build manually:

```bash
# macOS
brew install zstd brotli
zig build -Doptimize=ReleaseFast

# Linux
sudo apt-get install -y libzstd-dev libbrotli-dev
zig build -Doptimize=ReleaseFast
```

## Usage

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';

export default {
  plugins: [
    zcompress({
      algo: 'brotli',   // 'gzip' | 'zstd' | 'brotli'
      level: 9,         // 1-9
      threads: 0,       // 0 = auto
      cache: true,      // skip unchanged files
    })
  ]
};
```

After `vite build`, compressed assets are written to `dist-compressed/`.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `algo` | `'gzip' \| 'zstd' \| 'brotli'` | `'gzip'` | Compression algorithm |
| `level` | `number` | `6` | Compression level (1-9) |
| `threads` | `number` | `0` | Thread count (0=auto) |
| `verbose` | `boolean` | `false` | Verbose output |
| `cache` | `boolean` | `false` | Skip unchanged files |
| `include` | `string[]` | `[]` | Extra extensions to compress |
| `exclude` | `string[]` | `[]` | Extensions to skip |
| `binaryPath` | `string` | auto | Override binary path |
| `failOnError` | `boolean` | `true` | Fail `vite build` when compression fails |

## Troubleshooting

### `postinstall` binary download returns 404

If you see:

```txt
https://github.com/luochuan2008/zcompress/releases/download/vX.Y.Z/zcompress-macos-arm64 → 404
```

that npm version exists, but the matching GitHub Release binary asset is missing.

Workarounds:

1. Install/build the CLI manually
2. Set `binaryPath` explicitly

```js
zcompress({
  binaryPath: '/absolute/path/to/zcompress',
})
```

Or use env var (no code change):

```bash
export ZCOMPRESS_BINARY=/absolute/path/to/zcompress
npm run build
```

Default `failOnError: true` ensures builds fail loudly (instead of silently skipping compression).

## License

MIT
