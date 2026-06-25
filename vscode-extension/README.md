# Toast Terminal Focus (VS Code extension)

Companion extension for [claude-code-toast-notify](https://github.com/takaaaaaan/claude-code-toast-notify).

Clicking a Claude Code desktop toast normally brings the VS Code **window** to the
foreground. With this extension installed, the click focuses the **exact terminal
tab** Claude is running in — even when several terminals share the same workspace
folder, and even across multiple VS Code windows.

## How it works

The toast carries the hook process's ancestor PID chain. VS Code's
`Terminal.processId` (the terminal's shell PID) is always in that chain. Every
VS Code window runs this extension and watches a shared request file
(`~/.claude/.cctoast-focus.json`); the window that owns the matching terminal
focuses it. A `vscode://` URI handler is also registered as a direct path.

## Install

**From the Marketplace** (once published): search "Toast Terminal Focus" in the
Extensions view, or:

```
ext install takaaaaaan.terminal-focus
```

**From source (VSIX):**

```powershell
npx --yes @vscode/vsce package
code --install-extension terminal-focus-0.3.0.vsix
```

## Requirements

- VS Code with shell integration enabled (default).
- The `claude-code-toast-notify` hook installed (it embeds the PID chain).

## License

MIT
