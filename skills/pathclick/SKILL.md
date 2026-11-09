---
name: pathclick
description: Use when sharing local file artifacts as clickable links, resolving relative file references from a coding agent session, or opening a file with its default app or an app chooser.
---

# pathclick

Resolve paths against the working directory of the agent session that produced
them. Do not guess the project from the terminal title or another session.
The bundled helper needs Node.js 22.20+; it has no npm dependencies.

Use the actual installed directory containing this SKILL.md as `<skill-dir>`:

```sh
node "<skill-dir>/scripts/pathclick.mjs" link "src/report final.pdf:12" --cwd "<project-dir>" --format uri
node "<skill-dir>/scripts/pathclick.mjs" open "src/report final.pdf" --cwd "<project-dir>"
node "<skill-dir>/scripts/pathclick.mjs" open "src/report final.pdf" --cwd "<project-dir>" --choose
```

`link` checks existence, expands `~`, resolves relative paths, and removes a
trailing `:line[:column]` only if the exact filename does not exist. The default
app opens the file, without a promise to navigate to that line.

For a final answer, use the renderer's supported local-file Markdown format and
an absolute path. If unknown, offer the returned `file:` URI as a Markdown link
and a quoted helper command as fallback. Escape brackets in labels. Do not claim
the link was clicked or the file opened when you only generated a link.

For direct terminal output, `link --format osc8` emits an OSC 8 hyperlink.
Plain `link` chooses OSC 8 only on a TTY with TERM other than dumb; redirected
output is a URI. Tool-output viewers may strip escapes or block file links.
Run `open` only when the user requests opening, not just when sharing an artifact.

The opener runs on the machine executing the command. For SSH, WSL, containers
and remote agents, do not present a remote path as a working local link; explain
which filesystem it belongs to and use the agent's supported download/mapping.

Windows uses the associated app / native Open With dialog; macOS uses open /
Choose Application; Linux uses xdg-open / GTK 3 AppChooser (Python 3 + PyGObject
required for --choose). A graphical desktop and file associations are required.
CLI app choice does not change the default association. Cancellation opens nothing.

Ctrl/Cmd+Click, hover underlining and file-URI handling belong to the terminal.
The optional AutoHotkey helper adds pulsing hover, Ctrl+Click and
Ctrl+Shift+Click to Windows Terminal only, for existing absolute paths.
Do not promise these gestures, animation, or automatic interception of all agent
output on every OS or terminal. In unsupported terminals use the opener command.
