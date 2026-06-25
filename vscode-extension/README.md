# Claude Toast Terminal Focus (VS Code extension)

Companion extension for [claude-code-toast-notify](https://github.com/takaaaaaan/claude-code-toast-notify).

Clicking a Claude Code toast normally brings the VS Code **window** to the
foreground. With this extension installed, the click focuses the **exact
terminal tab** Claude is running in — even when several terminals share the
same workspace folder.

## How it works

The toast carries the hook process's ancestor PID chain. VS Code's
`Terminal.processId` (the terminal's shell PID) is always in that chain, so the
extension focuses the terminal whose `processId` matches. It registers a URI
handler for:

```
vscode://claude-toast.terminal-focus/focus?pids=<comma-separated pids>
```

## Install

Build a VSIX and install it:

```powershell
cd vscode-extension
npx --yes @vscode/vsce package
code --install-extension terminal-focus-0.1.0.vsix
```

Then reload VS Code. The PowerShell handler auto-detects the extension and
routes clicks to it; without the extension it falls back to window focus.

## Requirements

- VS Code with shell integration enabled (default).
- The `claude-code-toast-notify` hook installed (it embeds the PID chain).

## License

MIT
