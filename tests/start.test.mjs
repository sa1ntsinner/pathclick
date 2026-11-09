import test, { mock } from 'node:test';
import assert from 'node:assert/strict';
import childProcess from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

test('the Claude startup hook skips the Windows helper on other systems', async () => {
  const hook = new URL('../scripts/session-start.mjs', import.meta.url);
  assert.ok(existsSync(hook), 'A portable SessionStart entry point must exist');
  const { start } = await import(hook);
  const calls = [];
  const spy = mock.method(childProcess, 'spawnSync', (...args) => { calls.push(args); return { status: 0 }; });
  try {
    start('darwin');
    start('linux');
    assert.equal(calls.length, 0);
    start('win32');
    assert.equal(calls.length, 1);
    assert.equal(calls[0][0], 'powershell.exe');
    assert.ok(calls[0][1].includes(fileURLToPath(new URL('../scripts/start.ps1', import.meta.url))));
    assert.equal(calls[0][2].windowsHide, true);
  } finally { spy.mock.restore(); }
});
