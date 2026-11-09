#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import childProcess from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

export function resolvePath(input, cwd = process.cwd()) {
  if (!input || /[\x00-\x1f\x7f-\x9f]/u.test(input)) throw new Error('Invalid path or terminal control character');
  let value = input;
  if (/^file:/i.test(value)) value = fileURLToPath(value);
  else if (/^[a-z][a-z\d+.-]*:\/\//i.test(value)) throw new Error('Only local file paths are supported');
  if (/^~[/\\]/.test(value) || value === '~') value = os.homedir() + value.slice(1);
  let target = path.resolve(cwd, value);
  if (!fs.existsSync(target)) target = path.resolve(cwd, value.replace(/:\d+(?::\d+)?$/, ''));
  fs.statSync(target); // Fail before emitting a link or launching any application.
  return target;
}

export function formatLink(target, label, format) {
  const uri = pathToFileURL(target).href;
  if (format === 'uri') return uri;
  if (format === 'markdown') return `[${label.replace(/[\\[\]]/g, '\\$&')}](${uri.replaceAll('(', '%28').replaceAll(')', '%29')})`;
  return `\x1b]8;;${uri}\x1b\\${label}\x1b]8;;\x1b\\`;
}

export function openPath(target, choose = false, platform = process.platform) {
  let executable, args;
  const options = { stdio: 'inherit', windowsHide: true, env: { ...process.env, PATHCLICK_TARGET: target } };
  if (platform === 'win32') {
    executable = 'powershell.exe';
    args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File',
      fileURLToPath(new URL('./open-windows.ps1', import.meta.url)), ...(choose ? ['-Choose'] : [])];
  } else if (platform === 'darwin') {
    executable = choose ? 'osascript' : 'open';
    args = choose ? ['-e', `on run argv
  try
    set chosenApp to choose application with prompt "Open file with:"
    tell chosenApp to open (POSIX file (item 1 of argv))
  on error messageText number errorNumber
    if errorNumber is not -128 then error messageText number errorNumber
  end try
end run`, target] : [target];
  } else if (platform === 'linux') {
    executable = choose ? 'python3' : 'xdg-open';
    args = choose ? [fileURLToPath(new URL('./choose-linux.py', import.meta.url)), target] : [target];
  } else throw new Error(`Unsupported desktop OS: ${platform}`);
  const result = childProcess.spawnSync(executable, args, options);
  if (result.error) throw new Error(`${executable}: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`${executable} exited with ${result.status ?? result.signal}`);
}

export function main(args) {
  const command = args.shift();
  if (!command || command === '--help' || command === '-h') {
    console.log('Usage: pathclick link PATH [--cwd DIR] [--format uri|markdown|osc8]\n       pathclick open PATH [--cwd DIR] [--choose]\nUse -- before a filename that starts with -. Node.js 22.20+ required.');
    return;
  }
  if (!['link', 'open'].includes(command)) throw new Error(`Unknown command: ${command}`);
  let input, choose = false, cwd = process.cwd(), format = process.stdout.isTTY && process.env.TERM !== 'dumb' ? 'osc8' : 'uri';
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--cwd' || arg === '--format') {
      if (arg === '--format' && command !== 'link') throw new Error('--format requires link');
      const value = args[++i];
      if (!value || value.startsWith('--')) throw new Error(`Missing value for ${arg}`);
      if (arg === '--cwd') cwd = value;
      else format = value;
    } else if (arg === '--choose' && command === 'open') choose = true;
    else if (arg === '--') {
      if (input !== undefined || i + 2 !== args.length) throw new Error('Expected one path after --');
      input = args[++i];
    } else if (arg.startsWith('-') || input !== undefined) throw new Error(`Unexpected argument: ${arg}`);
    else input = arg;
  }
  if (!['uri', 'markdown', 'osc8'].includes(format)) throw new Error(`Unknown format: ${format}`);
  const target = resolvePath(input, cwd);
  if (command === 'open') openPath(target, choose);
  else console.log(formatLink(target, input, format));
}

if (process.argv[1] && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(`pathclick: ${error.message}`); process.exitCode = 1; }
}
