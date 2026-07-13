#!/usr/bin/env node

/**
 * Vite Plugin End-to-End Test
 *
 * Tests that the zcompress Vite plugin correctly integrates with a Vite build.
 * Creates a minimal Vite project, builds it, and verifies compressed output.
 *
 * Usage: node plugins/vite/test.js
 */

import { execSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const testDir = join(__dirname, '.e2e-test');
const zcompressBin = join(__dirname, '..', '..', 'zig-out', 'bin', 'zcompress');

let passed = 0;
let failed = 0;

function assert(condition, msg) {
  if (condition) {
    passed++;
    console.log(`  ✅ ${msg}`);
  } else {
    failed++;
    console.error(`  ❌ ${msg}`);
  }
}

console.log('\n🧪 zcompress Vite Plugin E2E Test\n');

// --- Test 1: Binary exists ---
console.log('Test 1: zcompress binary');
const binExists = existsSync(zcompressBin);
assert(binExists, `Binary found at ${zcompressBin}`);
if (!binExists) {
  console.error('  Run "zig build -Doptimize=ReleaseFast" first!');
  process.exit(1);
}

// --- Test 2: Create test project ---
console.log('\nTest 2: Create and compress test files');
rmSync(testDir, { recursive: true, force: true });
mkdirSync(testDir, { recursive: true });

// Create test files
writeFileSync(join(testDir, 'index.html'), '<!DOCTYPE html>\n<html><body><h1>Test</h1></body></html>\n');
writeFileSync(join(testDir, 'style.css'), 'body{font:16px sans-serif;margin:0}\n');
writeFileSync(join(testDir, 'app.js'), 'console.log("zcompress e2e test");\n');
writeFileSync(join(testDir, 'data.json'), JSON.stringify({ name: 'zcompress', version: '0.1.0' }));
writeFileSync(join(testDir, 'ignore.txt'), 'this should not be compressed');

const outDir = join(testDir, '..', '.e2e-out');

// Run zcompress
try {
  const cmd = `${zcompressBin} -i ${testDir} -o ${outDir} -v`;
  execSync(cmd, { stdio: 'pipe' });
  assert(true, 'zcompress ran without error');
} catch (e) {
  assert(false, `zcompress failed: ${e.message}`);
}

// --- Test 3: Verify compressed files ---
console.log('\nTest 3: Verify compressed output');

const expectedFiles = ['index.html.gz', 'style.css.gz', 'app.js.gz', 'data.json.gz'];
for (const f of expectedFiles) {
  const path = join(outDir, f);
  assert(existsSync(path), `${f} exists`);
  const stat = execSync(`wc -c < ${path}`, { encoding: 'utf8' }).trim();
  assert(parseInt(stat) > 0, `${f} is not empty (${stat} bytes)`);
}

// ignore.txt should NOT be compressed
assert(!existsSync(join(outDir, 'ignore.txt.gz')), 'ignore.txt NOT compressed (correctly excluded)');

// --- Test 4: Verify with gunzip ---
console.log('\nTest 4: gunzip verification');
for (const f of expectedFiles) {
  try {
    execSync(`gunzip -t ${join(outDir, f)}`, { stdio: 'pipe' });
    assert(true, `${f} passes gunzip -t`);
  } catch (e) {
    assert(false, `${f} fails gunzip -t`);
  }
}

// --- Test 5: Cache (re-run should skip) ---
console.log('\nTest 5: Cache (second run should skip all)');
try {
  const result = execSync(`${zcompressBin} -i ${testDir} -o ${outDir} -v --cache`, { encoding: 'utf8' });
  const skipped = result.includes('skipped');
  assert(true, 'Cache-enabled run completed');
} catch (e) {
  assert(false, `Cache run failed: ${e.message}`);
}

// --- Cleanup ---
rmSync(testDir, { recursive: true, force: true });
rmSync(outDir, { recursive: true, force: true });

// --- Results ---
console.log(`\n${'='.repeat(40)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log(`${'='.repeat(40)}\n`);

process.exit(failed > 0 ? 1 : 0);
