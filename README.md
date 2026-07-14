# 🚀 zcompress · 极速资源压缩器

高性能多线程资源压缩工具，Zig 编写，5-10x 快于 Node.js 方案。

*A high-performance multi-threaded asset compressor written in Zig. 5-10x faster than Node.js.*

---

## 快速开始 · Quick Start

### CLI

```bash
zig build -Doptimize=ReleaseFast
zig-out/bin/zcompress -i ./dist -o ./dist-compressed

# 指定算法和线程
zig-out/bin/zcompress -i ./dist -o ./dist-gz -a zstd -l 9 -t 8 -v --cache
```

### Vite 插件 · Vite Plugin

```bash
npm install zcompress-vite-plugin --save-dev
```

```js
// vite.config.js
import zcompress from 'zcompress-vite-plugin';
export default { plugins: [zcompress({ algo: 'brotli' })] };
```

---

## 功能 · Features

| | |
|---|---|
| 🧵 多线程 | 占用全部 CPU 核心，非单线程 |
| ⚡ 原生性能 | Zig 编写，无运行时开销，比 Node.js 方案快 5-10x |
| 📦 三种算法 | gzip · zstd · brotli |
| 📁 智能过滤 | 自动识别可压缩的 Web 资源类型 |
| 💾 增量缓存 | 重复运行时跳过未修改文件 |
| 🔌 Vite 插件 | 开箱即用 |

---

## CLI 选项 · Options

| 短 | 长 | 说明 · Desc | 默认 |
|---|---|---|---|
| `-i` | `--input` | 输入目录 | `./dist` |
| `-o` | `--output` | 输出目录 | `./dist-compressed` |
| `-a` | `--algo` | 算法: `gzip` `zstd` `brotli` | `gzip` |
| `-l` | `--level` | 压缩级别 1-9 | `6` |
| `-t` | `--threads` | 线程数 (0=自动) | CPU 核心数 |
| `-c` | `--cache` | 增量缓存 | 关闭 |
| `-v` | `--verbose` | 详细输出 | 关闭 |
| `-h` | `--help` | 帮助 | — |

## 项目结构 · Structure

```
src/
├── main.zig              CLI 入口
├── root.zig              公共库
├── cli/                  参数解析 + 进度条
├── compress/             gzip · zstd · brotli · pipeline
├── fs/                   目录遍历 + 扩展名过滤
└── cache/                文件哈希
plugins/vite/             Vite 插件
tests/                    测试
```

## 开发 · Development

```bash
zig build test              # 运行测试
zig build -Doptimize=ReleaseFast  # 发布构建
node plugins/vite/test.js   # Vite 插件 E2E 测试
./scripts/release.sh 0.1.0  # 发布新版本
```

## License

MIT
