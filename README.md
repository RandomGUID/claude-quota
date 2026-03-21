# claude-quota

![macOS](https://img.shields.io/badge/macOS-only-lightgrey?logo=apple)
![License: MIT](https://img.shields.io/badge/license-MIT-blue)

Pause Claude Code when your usage limit hits. Resume when it resets.

Runs multiple Claude Code instances overnight without burning extra credits.
When either the 5-hour or weekly limit is exceeded, each instance finishes
its current response and stops. When the limit resets, they resume automatically.

## Requirements

- macOS
- Claude Code CLI
- Google Chrome with a `claude.ai` tab open

## Install

```sh
git clone https://github.com/RandomGUID/claude-quota
cd claude-quota
./install.sh
```

`install.sh` puts the scripts in `~/bin` by default. To install elsewhere:

```sh
CLAUDE_QUOTA_BIN=/usr/local/bin ./install.sh
```

After installing, enable Chrome AppleScript access (one-time):

> Chrome → View → Developer → Allow JavaScript from Apple Events

Then verify everything is wired up:

```sh
claude-probe --check
```

## Usage

Run `claude-watch` instead of `claude`, from your worktree directory:

```sh
cd ~/projects/my-feature-branch
claude-watch
```

That's it. When a limit is hit, you'll see:

```
[claude-quota] Usage limit hit. Pausing until Mon Mar 23 at 11:00 AM PDT (237 min).
```

And when it resets, Claude resumes automatically.

Multiple instances work independently — run `claude-watch` in as many terminals
as you like. They share the same usage pool and coordinate through a shared flag
file (`~/.claude/limit_reset_at`).

## When Chrome isn't available

By default, if `claude-probe` can't reach Chrome or find a `claude.ai` tab, it
**pauses Claude** rather than continuing. This is a deliberate choice: if Chrome
closes at 3am while you're asleep, you don't silently burn extra credits.

To opt into the opposite behaviour:

```sh
export CLAUDE_QUOTA_ON_PROBE_FAILURE=continue
```

See [DESIGN.md](DESIGN.md) for the full rationale.

## How it works

See [DESIGN.md](DESIGN.md).

The short version: `claude-probe` runs a `fetch()` call inside a live Chrome
`claude.ai` tab via AppleScript. The tab doesn't need to be active — Chrome
doesn't switch windows or change anything visible. The probe reads the real
usage API that claude.ai uses for its own settings page, so the numbers are
always accurate.

## Caveats

- Chrome must be running with a `claude.ai` tab open.
- The VS Code Claude extension is unaffected — Stop hooks only fire for Claude Code CLI.
- Monthly extra-usage cap is not checked — manage it in your claude.ai account settings.
- Other browsers (Safari, Firefox) are not supported.

## Autonomous work loops (`claude-go`)

`claude-watch` is for interactive sessions — it resumes the same conversation when
a limit resets. For **autonomous, unattended work** where Claude picks up tasks
from a shared queue, use `claude-go` instead:

```sh
cd ~/trees/worktree1
claude-go "/go" --dangerously-skip-permissions
```

`claude-go` runs `claude -p <prompt>` in a loop. Each iteration gets a fresh
context — no `--resume`, no accumulated history. Between iterations it checks
quota and waits if a limit is hit.

This is designed for multi-worktree setups where each instance reads a build plan,
claims the next available task, does the work, opens a PR, and exits. The loop
restarts with fresh context for the next task.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_GO_TIMEOUT` | `60` | Minutes before a session is killed. Set to `0` to disable. |
| `CLAUDE_GO_COOLDOWN` | `10` | Seconds between iterations. Prevents tight loops on fast failures. |
| `CLAUDE_QUOTA_ON_PROBE_FAILURE` | `stop` | Inherited from claude-quota. |

### Example: 4 parallel worktrees

```sh
for i in 1 2 3 4; do
    (cd ~/trees/claude$i && claude-go "/go" --dangerously-skip-permissions &)
done
```

Each instance self-arranges by checking remote branches to see which tasks are
already claimed. See the `claude-go --help` header for full usage.

## Using `claude -p` for one-shot tasks

The Stop hook's `stop_hook_active` guard prevents the second-turn output-swallowing
issue that affected earlier versions. One-shot `claude -p` calls work without any
special environment variables. For CI environments where Chrome isn't available:

```yaml
env:
  CLAUDE_QUOTA_ON_PROBE_FAILURE: continue
```
