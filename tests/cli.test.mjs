import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const cli = fileURLToPath(new URL('../skills/pathclick/scripts/pathclick.mjs', import.meta.url));
const root = realpathSync(mkdtempSync(path.join(tmpdir(), 'pathclick-')));
mkdirSync(path.join(root, 'src'));
const file = path.join(root, 'src', 'hello world #1.txt');
writeFileSync(file, 'hello');
process.on('exit', () => rmSync(root, { recursive: true, force: true }));
const run = (...args) => spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8' });

test('relative paths resolve against the explicit project, including spaces and URI escaping', () => {
  const r = run('link', 'src/hello world #1.txt', '--cwd', root);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout.trim(), pathToFileURL(file).href);
});

test('line and column suffixes resolve to the file, without pretending the default app jumps to a line', () => {
  const r = run('link', 'src/hello world #1.txt:12:3', '--format', 'uri');
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout.trim(), pathToFileURL(file).href);
});

test('OSC 8 output links the complete path and closes the hyperlink', () => {
  const r = run('link', file, '--format', 'osc8');
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout, `\x1b]8;;${pathToFileURL(file).href}\x1b\\${file}\x1b]8;;\x1b\\\n`);
});

test('markdown output carries a file URI and escapes the label', () => {
  const r = run('link', file, '--format', 'markdown');
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout.trim(), `[${file.replaceAll('\\', '\\\\')}](${pathToFileURL(file).href})`);
});

test('a file URI can be reopened without treating percent escapes as a filename', () => {
  const r = run('link', pathToFileURL(file).href);
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout.trim(), pathToFileURL(file).href);
});

test('markdown destinations stay intact for filenames with unmatched parentheses', () => {
  writeFileSync(path.join(root, 'report).txt'), 'report');
  const r = run('link', 'report).txt', '--format', 'markdown');
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /report%29\.txt\)\n$/);
});

test('tilde expansion and Unicode file paths survive URI round trips', () => {
  const uri = run('link', '~', '--format', 'uri');
  assert.equal(uri.status, 0, uri.stderr);
  assert.ok(fileURLToPath(uri.stdout.trim()).length > 1);
  writeFileSync(path.join(root, 'отчёт.txt'), 'test');
  const r = run('link', 'отчёт.txt');
  assert.equal(r.status, 0, r.stderr);
  assert.equal(fileURLToPath(r.stdout.trim()), path.join(root, 'отчёт.txt'));
});

test('missing files and non-file URLs fail without producing links', () => {
  for (const value of ['missing.txt', 'https://example.com/file', 'src/hello\x1b]8;;evil.txt']) {
    const r = run('link', value);
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
    assert.match(r.stderr, /pathclick:/);
  }
});

test('unknown flags and missing option values are rejected', () => {
  for (const args of [['link', file, '--format', 'bad'], ['link', file, '--cwd'], ['open', file, '--oops']]) {
    const r = run(...args);
    assert.equal(r.status, 1);
    assert.equal(r.stdout, '');
  }
});

test('opening a missing file fails before launching a native handler', () => {
  const r = run('open', 'missing.txt', '--choose');
  assert.equal(r.status, 1);
  assert.match(r.stderr, /ENOENT/);
});

test('directories and option-like filenames are accepted after --', () => {
  writeFileSync(path.join(root, '--report.txt'), 'report');
  const r = run('link', '--', '--report.txt');
  assert.equal(r.status, 0, r.stderr);
  assert.equal(r.stdout.trim(), pathToFileURL(path.join(root, '--report.txt')).href);
  assert.equal(run('link', 'src').status, 0);
});

test('an exact filename wins over a location suffix on Unix', { skip: process.platform === 'win32' }, () => {
  writeFileSync(path.join(root, 'report:12'), 'report');
  assert.equal(run('link', 'report:12').stdout.trim(), pathToFileURL(path.join(root, 'report:12')).href);
});
