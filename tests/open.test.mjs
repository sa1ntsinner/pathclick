import test, { mock } from 'node:test';
import assert from 'node:assert/strict';
import childProcess from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import * as cli from '../skills/pathclick/scripts/pathclick.mjs';

const root = mkdtempSync(path.join(tmpdir(), 'pathclick-open-'));
const target = path.join(root, "a ' & $(touch bad) file.txt");
writeFileSync(target, 'test');
process.on('exit', () => rmSync(root, { recursive: true, force: true }));

test('native open keeps shell-looking filenames as data on every desktop OS', () => {
  assert.equal(typeof cli.openPath, 'function');
  const calls = [];
  const spy = mock.method(childProcess, 'spawnSync', (...args) => { calls.push(args); return { status: 0 }; });
  try {
    for (const platform of ['win32', 'darwin', 'linux']) cli.openPath(target, false, platform);
    assert.equal(calls[0][0], 'powershell.exe');
    assert.equal(calls[0][2].env.PATHCLICK_TARGET, target);
    assert.equal(calls[0][2].windowsHide, true);
    assert.deepEqual(calls[1].slice(0, 2), ['open', [target]]);
    assert.deepEqual(calls[2].slice(0, 2), ['xdg-open', [target]]);
    assert.ok(calls.every((c) => !c[2].shell));
  } finally { spy.mock.restore(); }
});

test('app choice is routed to native helpers without interpolating filenames into scripts', () => {
  assert.equal(typeof cli.openPath, 'function');
  const calls = [];
  const spy = mock.method(childProcess, 'spawnSync', (...args) => { calls.push(args); return { status: 0 }; });
  try {
    for (const platform of ['win32', 'darwin', 'linux']) cli.openPath(target, true, platform);
    assert.ok(calls[0][1].includes('-Choose'));
    assert.equal(calls[0][2].env.PATHCLICK_TARGET, target);
    assert.equal(calls[1][0], 'osascript');
    assert.equal(calls[1][1].at(-1), target);
    assert.ok(!calls[1][1][1].includes(target));
    assert.equal(calls[2][0], 'python3');
    assert.equal(calls[2][1].at(-1), target);
  } finally { spy.mock.restore(); }
});

test('launcher failures and unsupported systems are reported instead of claiming success', () => {
  assert.equal(typeof cli.openPath, 'function');
  const spy = mock.method(childProcess, 'spawnSync', () => ({ status: 3 }));
  try {
    assert.throws(() => cli.openPath(target, false, 'linux'), /3/);
    assert.throws(() => cli.openPath(target, false, 'unknown'), /Unsupported/);
    spy.mock.mockImplementation(() => ({ error: new Error('ENOENT') }));
    assert.throws(() => cli.openPath(target, false, 'linux'), /ENOENT/);
  } finally { spy.mock.restore(); }
});

test('macOS can compile the native chooser script without opening a dialog', { skip: process.platform !== 'darwin' }, () => {
  let script;
  const spy = mock.method(childProcess, 'spawnSync', (_file, args) => { script = args[1]; return { status: 0 }; });
  try { cli.openPath(target, true, 'darwin'); }
  finally { spy.mock.restore(); }
  const result = childProcess.spawnSync('osacompile', ['-o', path.join(root, 'chooser.scpt'), '-e', script], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
});
