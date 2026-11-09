import childProcess from 'node:child_process';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

export function start(platform = process.platform) {
  if (platform !== 'win32') return;
  const result = childProcess.spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive',
    '-ExecutionPolicy', 'Bypass', '-File', fileURLToPath(new URL('./start.ps1', import.meta.url))],
  { windowsHide: true, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Windows helper exited with ${result.status ?? result.signal}`);
}

if (process.argv[1] && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { start(); }
  catch (error) { console.error(`pathclick: ${error.message}`); process.exitCode = 1; }
}
