# zcompress-vite-plugin · 中文

Vite 生产构建资源压缩插件 — gzip / zstd / brotli，多线程并行，比 Node.js 方案快 5-10 倍。

## 安装

```bash
npm install zcompress-vite-plugin --save-dev
```

安装后自动下载对应平台的 zcompress 二进制。如果下载失败，手动安装：

```bash
brew install zcompress          # macOS
zig build install               # 从源码编译
```

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

`vite build` 后，`dist-compressed/` 目录下就是压缩后的文件：

```
dist-compressed/
├── index.html.gz
├── style.css.gz
├── app.js.gz
└── logo.svg.gz
```

配合 Nginx 的 `gzip_static on` 直接使用。

## 选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `algo` | `'gzip' \| 'zstd' \| 'brotli'` | `'gzip'` | 压缩算法 |
| `level` | `number` | `6` | 压缩级别 (1-9) |
| `threads` | `number` | `0` | 线程数 (0=CPU 核心数) |
| `verbose` | `boolean` | `false` | 显示详细输出 |
| `cache` | `boolean` | `false` | 跳过未修改文件 |
| `include` | `string[]` | `[]` | 额外压缩的扩展名 (如 `['.ts']`) |
| `exclude` | `string[]` | `[]` | 排除的扩展名 (如 `['.map']`) |
| `binaryPath` | `string` | 自动 | 手动指定二进制路径 |

## 默认压缩的文件类型

`.js` `.mjs` `.cjs` `.css` `.html` `.htm` `.json` `.svg` `.png` `.jpg` `.jpeg` `.gif` `.ico` `.ttf` `.woff` `.woff2` `.xml` `.csv` `.wasm`

## License

MIT

---

# zcompress-vite-plugin · English

High-performance multi-threaded asset compression for Vite production builds. 5-10x faster than Node.js alternatives.

## Install

```bash
npm install zcompress-vite-plugin --save-dev
```

The correct platform binary is downloaded automatically. If that fails:

```bash
brew install zcompress          # macOS
zig build install               # from source
```

## Usage

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';

export default {
  plugins: [
    zcompress({
      algo: 'brotli',   // 'gzip' | 'zstd' | 'brotli'
      level: 11,        // 1-9
      threads: 0,       // 0 = auto
      cache: true,      // skip unchanged files
    })
  ]
};
```

After `vite build`, find compressed assets in `dist-compressed/`:

```
dist-compressed/
├── index.html.br
├── style.css.br
├── app.js.br
└── logo.svg.br
```

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

## License

MIT
