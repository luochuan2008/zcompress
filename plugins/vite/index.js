/**
 * zcompress Vite Plugin
 *
 * A Vite plugin that compresses build output using the zcompress CLI.
 * Provides multi-threaded gzip/zstd/brotli compression for production builds.
 *
 * @example
 * // vite.config.js
 * import zcompress from 'zcompress-vite-plugin';
 *
 * export default {
 *   plugins: [
 *     zcompress({ algo: 'gzip', level: 6, threads: 4 })
 *   ]
 * };
 */

import { execFileSync } from 'node:child_process';
import { existsSync, statSync, readdirSync } from 'node:fs';
import { join, dirname, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * @typedef {Object} ZCompressOptions
 * @property {string} [algo='gzip'] - Compression algorithm: gzip, zstd, brotli
 * @property {number} [level=6] - Compression level: 1-9
 * @property {number} [threads=0] - Thread count (0 = auto)
 * @property {boolean} [verbose=false] - Verbose output
 * @property {boolean} [cache=false] - Enable incremental caching
 * @property {string[]} [include] - Extra file extensions to include
 * @property {string[]} [exclude] - File extensions to exclude
 * @property {string} [binaryPath] - Path to zcompress binary
 * @property {boolean} [failOnError=true] - Fail Vite build if compression fails
 */

/** @type {ZCompressOptions} */
const DEFAULT_OPTIONS = {
  algo: 'gzip',
  level: 6,
  threads: 0,
  verbose: false,
  cache: false,
  include: [],
  exclude: [],
  failOnError: true,
};

/**
 * Find the zcompress binary.
 * Order: 1) downloaded by postinstall 2) local zig build 3) PATH
 */
function findBinary() {
  // 1) postinstall-downloaded binary inside package
  const packagedBin = join(__dirname, 'bin', process.platform === 'win32' ? 'zcompress.exe' : 'zcompress');
  if (existsSync(packagedBin)) return packagedBin;

  // 2) local zig build
  const zigPaths = [
    join(process.cwd(), 'zig-out', 'bin', 'zcompress'),
    join(process.cwd(), 'zig-out', 'bin', 'zcompress.exe'),
  ];
  for (const p of zigPaths) {
    if (existsSync(p)) return p;
  }

  // 3) PATH
  return 'zcompress';
}

/**
 * Create the zcompress Vite plugin.
 *
 * @param {ZCompressOptions} userOptions
 * @returns {import('vite').Plugin}
 */
export default function zcompressPlugin(userOptions = {}) {
  const options = { ...DEFAULT_OPTIONS, ...userOptions };

  // ESM-safe plugin state (do not use `this`)
  let active = false;
  let resolvedOutDir = 'dist';

  return {
    name: 'zcompress',
    apply: 'build',
    enforce: 'post',

    configResolved(config) {
      active = config.command === 'build';

      // Save outDir from Vite config (Bug #2 fix)
      const configuredOutDir = config.build?.outDir || 'dist';
      resolvedOutDir = isAbsolute(configuredOutDir)
        ? configuredOutDir
        : join(config.root || process.cwd(), configuredOutDir);
    },

    closeBundle() {
      if (!active) return;

      const outDir = resolvedOutDir;
      const compressedDir = `${outDir}-compressed`;

      if (!existsSync(outDir)) {
        console.warn(`[zcompress] Output directory "${outDir}" not found. Skipping.`);
        return;
      }

      const binary = options.binaryPath || findBinary();
      const args = [
        '-i', outDir,
        '-o', compressedDir,
        '-a', options.algo,
        '-l', String(options.level),
      ];

      if (options.threads > 0) args.push('-t', String(options.threads));
      if (options.verbose) args.push('--verbose');
      if (options.cache) args.push('--cache');

      for (const ext of options.include) args.push(`--include=${ext}`);
      for (const ext of options.exclude) args.push(`--exclude=${ext}`);

      const cmd = `${binary} ${args.join(' ')}`;

      if (options.verbose) {
        console.log(`[zcompress] Running: ${cmd}`);
      }

      const startTime = Date.now();

      try {
        execFileSync(binary, args, { stdio: 'inherit' });
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

        const srcSize = getDirSize(outDir);
        const destSize = getDirSize(compressedDir);
        const savedPct = srcSize > 0
          ? ((1 - destSize / srcSize) * 100).toFixed(1)
          : '0.0';

        console.log(`[zcompress] ✅ Compressed ${formatSize(srcSize)} → ${formatSize(destSize)} (saved ${savedPct}%) in ${elapsed}s`);
      } catch (err) {
        const message = [
          `[zcompress] ❌ Compression failed: ${err.message}`,
          `[zcompress] Binary used: ${binary}`,
          '[zcompress] If this is a 404 download issue, GitHub Release may be missing prebuilt binaries for this version.',
          '[zcompress] Workaround: install CLI manually (`zig build -Doptimize=ReleaseFast`) and set `binaryPath` in plugin options.',
        ].join('\n');

        if (options.failOnError !== false) {
          throw new Error(message);
        }

        console.error(message);
      }
    },
  };
}

/**
 * Calculate total directory size in bytes.
 *
 * @param {string} dirPath
 * @returns {number}
 */
function getDirSize(dirPath) {
  if (!existsSync(dirPath)) return 0;

  let total = 0;
  try {
    walkDir(dirPath, (filePath) => {
      try {
        total += statSync(filePath).size;
      } catch {
        // ignore unreadable files
      }
    });
  } catch {
    // ignore traversal failures
  }
  return total;
}

/**
 * Recursively walk a directory.
 *
 * @param {string} dir
 * @param {(path: string) => void} fn
 */
function walkDir(dir, fn) {
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walkDir(full, fn);
      } else {
        fn(full);
      }
    }
  } catch {
    // ignore traversal failures
  }
}

/**
 * Format bytes into human-readable string.
 *
 * @param {number} bytes
 * @returns {string}
 */
function formatSize(bytes) {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const size = (bytes / Math.pow(1024, i)).toFixed(1);
  return `${size} ${units[Math.min(i, units.length - 1)]}`;
}
