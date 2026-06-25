const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Where the PowerShell handler drops a focus request. Every VS Code window runs
// this extension and watches the same file; the window that owns the matching
// terminal focuses it. This works across multiple windows because each window's
// extension host can only see its own terminals, but all of them watch one file.
function requestFile() {
  const dir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  return path.join(dir, '.cctoast-focus.json');
}

function parsePids(raw) {
  return String(raw || '')
    .split(',')
    .map((s) => parseInt(s, 10))
    .filter((n) => !Number.isNaN(n));
}

// Focus the terminal whose shell PID is in the ancestor chain. Returns true if
// a terminal matched (i.e. this window owns Claude's tab).
async function focusByPids(pids) {
  const set = new Set(pids);
  for (const term of vscode.window.terminals) {
    let pid;
    try {
      pid = await term.processId;
    } catch (e) {
      pid = undefined;
    }
    if (pid !== undefined && set.has(pid)) {
      term.show(false);
      return true;
    }
  }
  return false;
}

function handleRequest() {
  try {
    const file = requestFile();
    if (!fs.existsSync(file)) return;
    const data = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (!data || !data.ts) return;
    if (Date.now() - data.ts > 15000) return; // ignore stale requests
    focusByPids(parsePids(data.pids));
  } catch (e) {
    // ignore malformed / partial writes
  }
}

function activate(context) {
  // Direct path: vscode://claude-toast.terminal-focus/focus?pids=...
  context.subscriptions.push(
    vscode.window.registerUriHandler({
      handleUri: async (uri) => {
        const params = new URLSearchParams(uri.query || '');
        const ok = await focusByPids(parsePids(params.get('pids')));
        if (!ok) {
          try {
            await vscode.commands.executeCommand('workbench.action.terminal.focus');
          } catch (e) {
            // ignore
          }
        }
      },
    })
  );

  // Multi-window path: watch the shared request file in every window.
  try {
    const file = requestFile();
    const dir = path.dirname(file);
    const base = path.basename(file);
    if (fs.existsSync(dir)) {
      const watcher = fs.watch(dir, (event, fname) => {
        if (!fname || fname === base) handleRequest();
      });
      context.subscriptions.push({ dispose: () => watcher.close() });
    }
    handleRequest(); // pick up a request that arrived just before activation
  } catch (e) {
    // ignore
  }
}

function deactivate() {}

module.exports = { activate, deactivate };
