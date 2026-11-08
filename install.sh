#!/usr/bin/env bash
# Install codex-opussy as a Claude Code skill (+ optional enforcement hook).
#
#   curl -fsSL https://raw.githubusercontent.com/RestartFU/codex-opussy/master/install.sh | bash
#   ./install.sh              # install skill + hook
#   ./install.sh --no-hook    # skill only (Claude follows it via the skill description)
#   ./install.sh --uninstall  # remove hook entry and the skill directory
set -euo pipefail

REPO="https://github.com/RestartFU/codex-opussy.git"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/codex-opussy"
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
HOOK=1; UNINSTALL=0
for a in "$@"; do
  case "$a" in
    --no-hook) HOOK=0 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

hook_edit() {  # $1 = add|remove
  python3 - "$SETTINGS" "$DEST/hooks/guard-agent.py" "$1" <<'PY'
import json, os, sys
path, cmd, mode = sys.argv[1:4]
s = {}
if os.path.exists(path):
    with open(path) as f:
        s = json.load(f)
pre = s.setdefault("hooks", {}).setdefault("PreToolUse", [])
pre[:] = [g for g in pre if not any("codex-opussy" in h.get("command", "") for h in g.get("hooks", []))]
if mode == "add":
    pre.append({"matcher": "Agent", "hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
if not pre:
    s["hooks"].pop("PreToolUse")
if not s["hooks"]:
    s.pop("hooks")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(s, f, indent=2)
    f.write("\n")
PY
}

if [[ $UNINSTALL -eq 1 ]]; then
  hook_edit remove
  rm -rf "$DEST"
  echo "codex-opussy uninstalled."
  exit 0
fi

command -v codex >/dev/null || echo "warning: 'codex' CLI not on PATH — install it first (npm i -g @openai/codex) and run 'codex login'." >&2

if [[ -d "$DEST/.git" ]]; then
  git -C "$DEST" pull --ff-only --quiet
elif [[ -e "$DEST" ]]; then
  echo "$DEST exists and is not a git checkout; leaving it alone." >&2
else
  mkdir -p "$(dirname "$DEST")"
  git clone --quiet "$REPO" "$DEST"
fi
chmod +x "$DEST/bin/codex-agent" "$DEST/hooks/guard-agent.py"

if [[ $HOOK -eq 1 ]]; then
  hook_edit add
  echo "Registered PreToolUse hook on Agent in $SETTINGS"
fi

mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/codex-opussy"
echo "codex-opussy installed at $DEST"
echo "Personal overrides: ${XDG_CONFIG_HOME:-$HOME/.config}/codex-opussy/config  (see $DEST/config)"
echo "Restart Claude Code (or start a new session) to pick it up."
