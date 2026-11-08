# codex-opussy

A [Claude Code](https://claude.com/claude-code) skill that makes Claude run its subagents on **OpenAI Codex** instead of Claude. By default the agents use **GPT-6.1-Sol**, and the model is configurable.

Claude still decides *when* to delegate, exactly as it would have. This skill only changes *who* does the work. Codex agents can be less reliable than Claude Opus subagents, so Claude does a short sanity check on each report before acting on it. It reads the report for coherence and spot-checks the one to three claims that matter. It does not redo the agent's work.

## How it works

- **`SKILL.md`**: tells Claude to send every would-be `Agent` call to Codex, how to write a zero-context brief, how to map Agent types to sandbox and effort flags, how much checking to do, and when to fall back to Claude.
- **`bin/codex-agent`**: a wrapper around `codex exec`. It runs one headless Codex agent and prints only its final report, followed by a one-line footer with status, time and log path. The full transcript goes to `~/.local/state/codex-opussy/runs/`, so it stays out of Claude's context. It works with background and parallel Bash calls.
- **`hooks/guard-agent.py`** (optional): a `PreToolUse` hook on `Agent` that denies Claude-subagent calls and points Claude to `codex-agent`, so the rule is enforced and not just suggested. Claude can bypass it on purpose with a `[claude-subagent]` marker when Codex fails or the task needs Claude-only tools (MCP, browser and so on).

## Install

Requires the `codex` CLI (logged in), `git` and `python3`.

```bash
curl -fsSL https://raw.githubusercontent.com/RestartFU/codex-opussy/master/install.sh | bash
# or, skill only without the enforcement hook:
curl -fsSL https://raw.githubusercontent.com/RestartFU/codex-opussy/master/install.sh | bash -s -- --no-hook
```

This clones the repo to `~/.claude/skills/codex-opussy` and, unless you pass `--no-hook`, adds the hook to `~/.claude/settings.json`. Start a new Claude Code session afterwards. Run the script again to update. Pass `--uninstall` to remove it.

## Configure

Write `KEY=VALUE` lines in `~/.config/codex-opussy/config`. You can also set `CODEX_OPUSSY_<KEY>` env vars, or pass per-call flags to `codex-agent`.

```ini
ENABLED=1              # 0 = back to normal Claude subagents
MODEL=gpt-6.1-sol
EFFORT=medium          # low | medium | high | xhigh | max | ultra
SANDBOX=workspace-write
NETWORK=1
TIMEOUT=1800
HOOK=1                 # enforce via hook (if installed)
HOOK_ALLOW=statusline-setup
EXTRA_ARGS=
```

Run `~/.claude/skills/codex-opussy/bin/codex-agent --print-config` to see the effective settings.

## Manual use

```bash
codex-agent -n find-auth -s read-only -C ~/src/app - <<'EOF'
Find where session tokens are validated and list each call site with file:line.
EOF
```

## License

MIT
