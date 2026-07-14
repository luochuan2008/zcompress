declare module 'zcompress-vite-plugin' {
  interface ZCompressOptions {
    /** Compression algorithm: 'gzip' | 'zstd' | 'brotli' (default: 'gzip') */
    algo?: 'gzip' | 'zstd' | 'brotli';
    /** Compression level: 1-9 (default: 6) */
    level?: number;
    /** Thread count, 0 = auto (default: 0) */
    threads?: number;
    /** Verbose output (default: false) */
    verbose?: boolean;
    /** Enable incremental cache (default: false) */
    cache?: boolean;
    /** Extra file extensions to include (e.g. ['.ts', '.tsx']) */
    include?: string[];
    /** File extensions to exclude (e.g. ['.map']) */
    exclude?: string[];
    /** Override path to zcompress binary */
    binaryPath?: string;
    /** Fail Vite build if compression fails (default: true) */
    failOnError?: boolean;
  }

  import type { Plugin } from 'vite';

  function zcompressPlugin(options?: ZCompressOptions): Plugin;
  export default zcompressPlugin;
}
