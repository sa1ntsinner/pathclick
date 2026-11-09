# pathclick

Open files mentioned by coding agents without copying paths into another app.
Windows, macOS and Linux. Relative paths resolve from the agent's project folder.

## Install for your agents

```sh
npx skills add sa1ntsinner/pathclick -g -y -a codex claude-code cursor gemini-cli
```

Requires **Node.js 22.20+** and Git. Installs the skill and bundled helper for
these four agents. Change the list after `-a` for [other agents](https://github.com/vercel-labs/skills).
Agents without global skill support need project installation: omit `-g`.
Restart your agent, then ask it to use **pathclick** to link or open a file.

## Use without an agent

```sh
npx --yes --package github:sa1ntsinner/pathclick pathclick open ./README.md
npx --yes --package github:sa1ntsinner/pathclick pathclick open ./README.md --choose
npx --yes --package github:sa1ntsinner/pathclick pathclick link src/main.ts:12 --cwd /your/project
```

`open` uses the default app; `--choose` asks which app to use. `link` emits an
OSC 8 file link in a terminal, a file URI when redirected. Force a format with
`--format osc8|markdown|uri`. Paths must exist; quote spaces. `~`, directories,
file URIs and `:line[:column]` suffixes work. Line suffixes do not move the viewer.

## What works where

| Feature | Support |
| --- | --- |
| Resolve paths / generate links | Windows, macOS, Linux; any agent that loads SKILL.md |
| Open default app | Windows associations, macOS `open`, Linux `xdg-open` |
| Choose app | Windows/macOS native dialog; Linux needs Python 3 + PyGObject + GTK 3 |
| Click / underline | Terminal or agent renderer must support file links / OSC 8 |
| Pulsing hover + Ctrl+Shift+Click | Optional Windows Terminal + AutoHotkey v2 helper |

No skill can add mouse support to every terminal. Other terminals use their own
click modifiers and hover style; the CLI opener works without hyperlink support.
Opening requires a desktop. SSH/WSL/container paths refer to that environment.
See [compatibility and Windows setup](docs/compatibility.md).

## Claude Code plugin (optional)

```sh
claude plugin marketplace add sa1ntsinner/pathclick
claude plugin install pathclick@pathclick
```

Includes the same skill. On Windows, also starts the hover helper if AutoHotkey
v2 is installed. Other systems skip that helper. No background service is needed
for portable links. Choose either skill installation or plugin installation.

Tests: `npm test`. CI runs on Windows, macOS and Linux. [MIT](LICENSE).
