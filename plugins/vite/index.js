/**
 * zcompress Vite Plugin
 *
 * A Vite plugin that compresses build output using the zcompress CLI.
 * Provides multi-threaded gzip/zstd compression for production builds.
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

import { execSync } from 'node:child_process';
import { existsSync, statSync } from 'node:fs';
import { join } from 'node:path';

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
};

/**
 * Find the zcompress binary.
 * Order: 1) downloaded by postinstall  2) PATH  3) local zig build
 */
function findBinary() {
  // 1. Check for postinstall-downloaded binary
  const binDir = join(__dirname, 'bin');
  const localBin = join(binDir, process.platform === 'win32' ? 'zcompress.exe' : 'zcompress');
  if (existsSync(localBin)) return localBin;

  // 2. Check local zig build
  const zigPaths = [
    join(process.cwd(), 'zig-out', 'bin', 'zcompress'),
    join(process.cwd(), 'zig-out', 'bin', 'zcompress.exe'),
  ];
  for (const p of zigPaths) {
    if (existsSync(p)) return p;
  }

  // 3. Fall back to PATH
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

  return {
    name: 'zcompress',
    apply: 'build',
    enforce: 'post',

    configResolved(config) {
      // Only run in production build mode
      this.active = config.command === 'build';
    },

    closeBundle() {
      if (!this.active) return;

      const outDir = this.outDir || 'dist';
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

      if (options.threads > 0) {
        args.push('-t', String(options.threads));
      }
      if (options.verbose) args.push('--verbose');
      if (options.cache) args.push('--cache');

      for (const ext of options.include) {
        args.push(`--include=${ext}`);
      }
      for (const ext of options.exclude) {
        args.push(`--exclude=${ext}`);
      }

      const cmd = `${binary} ${args.join(' ')}`;

      if (options.verbose) {
        console.log(`[zcompress] Running: ${cmd}`);
      }

      const startTime = Date.now();

      try {
        execSync(cmd, { stdio: 'inherit' });
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

        // Calculate size stats
        const srcSize = getDirSize(outDir);
        const destSize = getDirSize(compressedDir);
        const savedPct = srcSize > 0
          ? ((1 - destSize / srcSize) * 100).toFixed(1)
          : '0.0';

        console.log(`[zcompress] ✅ Compressed ${formatSize(srcSize)} → ${formatSize(destSize)} (saved ${savedPct}%) in ${elapsed}s`);
      } catch (err) {
        console.error(`[zcompress] ❌ Compression failed: ${err.message}`);
        console.error('[zcompress] Make sure zcompress is installed: zig build install');
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
  // Simple approximation — list files and sum their sizes
  let total = 0;
  try {
    const { readdirSync } = require('node:fs');
    const { join } = require('node:path');
    walkDir(dirPath, (filePath) => {
      try {
        total += statSync(filePath).size;
      } catch (_) { /* ignore */ }
    });
  } catch (_) { /* ignore */ }
  return total;
}

/**
 * Recursively walk a directory.
 *
 * @param {string} dir
 * @param {(path: string) => void} fn
 */
function walkDir(dir, fn) {
  const { readdirSync } = require('node:fs');
  const { join } = require('node:path');
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
  } catch (_) { /* ignore */ }
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
