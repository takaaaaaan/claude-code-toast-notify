const vscode = require('vscode');

// Handles vscode://claude-toast.terminal-focus/focus?pids=<csv>
// The toast click carries the ancestor PID chain of the hook process. The
// terminal that Claude runs in has its shell PID somewhere in that chain
// (VS Code's terminal.processId == that shell), so we focus the terminal whose
// processId is in the set. This pinpoints the right tab even when several
// terminals share the same workspace folder.
function activate(context) {
  context.subscriptions.push(
    vscode.window.registerUriHandler({
      handleUri: async (uri) => {
        const params = new URLSearchParams(uri.query || '');
        const raw = params.get('pids') || '';
        const pids = new Set(
          raw.split(',').map((s) => parseInt(s, 10)).filter((n) => !Number.isNaN(n))
        );

        let target;
        for (const term of vscode.window.terminals) {
          let pid;
          try {
            pid = await term.processId;
          } catch (e) {
            pid = undefined;
          }
          if (pid !== undefined && pids.has(pid)) {
            target = term;
            break;
          }
        }

        if (target) {
          // reveal the panel and move keyboard focus into this terminal tab
          target.show(false);
        } else {
          // no match (e.g. stale pids) -> at least focus the terminal panel
          try {
            await vscode.commands.executeCommand('workbench.action.terminal.focus');
          } catch (e) {
            // ignore
          }
        }
      },
    })
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
