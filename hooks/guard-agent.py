#!/usr/bin/env python3
"""PreToolUse hook for the Agent tool: redirect Claude subagents to Codex.

When codex-opussy is enabled, a call to Claude's Agent tool is denied with a
message telling Claude to run the task through bin/codex-agent instead.

A call is let through when any of these hold:
  * ENABLED=0 or HOOK=0 in config (or CODEX_OPUSSY_ENABLED / CODEX_OPUSSY_HOOK env)
  * the subagent_type is in HOOK_ALLOW (comma-separated, default: statusline-setup)
  * the prompt contains the marker [claude-subagent]  (explicit fallback)
  * the codex CLI is not installed
"""
import json
import os
import re
import shutil
import sys

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
MARKER = "[claude-subagent]"

cfg = {"ENABLED": "1", "HOOK": "1", "HOOK_ALLOW": "statusline-setup"}


def load(path):
    try:
        with open(path) as f:
            for line in f:
                line = line.split("#", 1)[0]
                m = re.match(r"\s*([A-Z_]+)\s*=\s*(.*?)\s*$", line)
                if m:
                    cfg[m.group(1)] = m.group(2).strip('"')
    except OSError:
        pass


load(os.path.join(SKILL_DIR, "config"))
load(os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "codex-opussy", "config"))
for k in ("ENABLED", "HOOK", "HOOK_ALLOW"):
    if f"CODEX_OPUSSY_{k}" in os.environ:
        cfg[k] = os.environ[f"CODEX_OPUSSY_{k}"]


def off(v):
    return str(v).strip().lower() in ("0", "false", "no", "off", "")


try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if data.get("tool_name") != "Agent":
    sys.exit(0)
if off(cfg["ENABLED"]) or off(cfg["HOOK"]):
    sys.exit(0)
if not shutil.which("codex"):
    sys.exit(0)

ti = data.get("tool_input") or {}
sub = (ti.get("subagent_type") or "").strip()
allow = {s.strip() for s in cfg["HOOK_ALLOW"].split(",") if s.strip()}
if sub and sub in allow:
    sys.exit(0)
if MARKER in (ti.get("prompt") or ""):
    sys.exit(0)

runner = os.path.join(SKILL_DIR, "bin", "codex-agent")
reason = (
    "codex-opussy is active: subagents run on Codex, not Claude. "
    f"Re-issue this task via Bash: `{runner} -n <label> - <<'EOF' ... EOF` "
    "(use run_in_background: true for background/parallel agents; add `-s read-only` for "
    "search/research-only tasks). Then sanity-check the report per the codex-opussy skill. "
    f"Only if Codex fails or is unsuitable, retry the Agent call with {MARKER} in the prompt."
)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }
}))
