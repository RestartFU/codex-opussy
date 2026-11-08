---
name: codex-opussy
description: Run subagents on OpenAI Codex (default GPT-6.1-Sol) instead of Claude. Use this EVERY time you are about to call the Agent tool to spawn a Claude subagent (general-purpose, Explore, Plan, claude, fork, or any custom type) — delegate the same task to a Codex agent via this skill's bin/codex-agent script, then quickly sanity-check what it returns. Not for work you would do inline yourself, and not for Workflow scripts.
---

# codex-opussy — Codex subagents instead of Claude subagents

While this skill is enabled, **whenever you would have spawned a Claude subagent with the Agent tool, run a Codex agent instead.** Use subagents exactly as often as you would have anyway. This skill only changes who does the delegated work. It is not a reason to delegate more or less.

Codex is capable but **less reliable than a Claude Opus subagent**, so check its report briefly before you trust it (see "Check the result" below). Keep that check short.

## Is it on?

```bash
~/.claude/skills/codex-opussy/bin/codex-agent --print-config
```

If `ENABLED=0` in `~/.config/codex-opussy/config`, or `CODEX_OPUSSY_ENABLED=0` is set, ignore this skill and use the Agent tool normally. (The script shows the effective model, effort and sandbox settings. `ENABLED` lives only in the config files.)

## Dispatch

Run the task through Bash. Always pass the prompt on stdin with a quoted heredoc, so you never have to worry about quoting:

```bash
~/.claude/skills/codex-opussy/bin/codex-agent -n auth-audit -C /path/to/repo - <<'EOF'
<the brief you would have given the Claude subagent>
EOF
```

- **Background, the default for Claude agents:** set `run_in_background: true` on the Bash call. You are re-invoked when it exits, so don't poll.
- **Parallel agents:** send several background Bash calls in one message, each with its own `-n` label.
- **Need the result right away:** run it in the foreground with Bash `timeout: 600000`. Use background for anything longer.
- The script prints **only the agent's final report**, followed by a footer with status, elapsed time and the full log path. Read the log only if the report is confusing or the run failed.

### Map the Agent type you would have used to flags

| Would-be Agent call | codex-agent flags |
|---|---|
| `Explore` / research / "find where X is" | `-s read-only -e low` |
| `Plan` / design / review / audit | `-s read-only` (raise `-e high` for hard problems) |
| `general-purpose` / `claude` / implementation | defaults (`workspace-write`, network on) |
| work that must write outside the repo | `--add-dir DIR`, or `-s danger-full-access` if truly needed |
| `isolation: "worktree"` | create a worktree yourself (`git worktree add`), then pass `-C` with it |

Other flags: `-m MODEL`, `-e EFFORT`, `-t TIMEOUT_SECONDS`, `--no-network`. Run `--help` for the full list.

### Write the brief

Codex starts with **zero context**: no conversation, no CLAUDE.md, no memory. Write the brief the way you would for a Claude subagent, and be a bit more explicit:
- the goal, and why it matters
- absolute paths to the files and directories that matter, plus what you have already ruled out
- the scope, and what it must NOT touch
- the shape of the report you want back. For example: "list each finding with file:line and a one-line justification", or "end with the exact commands you ran and their output".

The script already tells Codex it reports to an AI, must not ask questions, and must give evidence.

## Check the result (short, not perfect)

Codex can be confidently wrong. Before you use or relay its report, spend **a little** effort on it, usually 1–3 cheap tool calls:

1. **Smell test (free):** Does it answer the question you asked? Is it internally consistent? Does it fit what you already know about the codebase? Watch for vague hand-waving, invented APIs or flags, and claims like "tests pass" with no command shown.
2. **Spot-check the claims that matter:** pick the one to three claims your next step depends on and verify them cheaply. Open the cited file:line, grep for the symbol, check `git diff --stat` after an edit task, or run the one test it says passes.
3. **Decide:**
   - Looks right and the spot-checks pass → use it and move on.
   - Small error → fix it yourself.
   - Wrong, or the spot-checks fail → re-dispatch once with a sharper brief that says what was wrong. If it fails again, do the work yourself, or fall back to a Claude subagent (below).

Do **not** redo the agent's whole investigation to "make sure". If checking would take as long as doing the work, accept reasonable risk and tell the user what you didn't verify. For code changes, a quick look at the diff plus one build or test run is enough.

When you relay results to the user, mention that a Codex agent produced them if that matters to how much they should trust the result.

## Falling back to a Claude subagent

Use the normal Agent tool when:
- `codex-agent` exits non-zero for reasons a retry won't fix (codex missing, auth error, unknown model), or it times out twice
- the task needs Claude-only tools Codex doesn't have: MCP servers in this session, Claude Docs, browser or computer-use tools, SendMessage to other agents
- the user explicitly asks for a Claude agent

If the enforcement hook is installed, put the literal marker `[claude-subagent]` anywhere in the Agent prompt so the hook lets the call through.

## Not covered

- **Workflow** scripts (multi-agent orchestration the user explicitly opted into) keep running on Claude.
- The `statusline-setup` agent stays on Claude (`HOOK_ALLOW` in config).
- Work you would do inline yourself stays inline. Don't start delegating trivial things to Codex.

## Configuration

Settings are `KEY=VALUE` lines. Each source overrides the one before it: the defaults in `~/.claude/skills/codex-opussy/config`, then `~/.config/codex-opussy/config`, then `CODEX_OPUSSY_<KEY>` env vars, then per-call flags.

| Key | Default | Meaning |
|---|---|---|
| `ENABLED` | `1` | master switch |
| `MODEL` | `gpt-6.1-sol` | Codex model |
| `EFFORT` | `medium` | reasoning effort (low…ultra) |
| `SANDBOX` | `workspace-write` | read-only / workspace-write / danger-full-access |
| `NETWORK` | `1` | network access inside workspace-write |
| `TIMEOUT` | `1800` | seconds before the agent is killed (0 = none) |
| `HOOK` | `1` | enforce via the PreToolUse hook, if installed |
| `HOOK_ALLOW` | `statusline-setup` | Agent types that stay on Claude |
| `EXTRA_ARGS` | — | raw extra `codex exec` args |
