# claude-quota

Pause Claude Code when your usage limit hits. Resume when it resets.

Runs multiple Claude Code instances overnight without burning extra credits.
When either the 5-hour or weekly limit is exceeded, each instance finishes
its current response and stops. When the limit resets, they resume automatically.

## How it works

`claude-quota` probes `claude.ai/api/.../usage` by running a `fetch()` inside
a live Chrome tab via AppleScript — the same session your browser already has,
no separate auth needed, no Cloudflare friction.

A global Stop hook checks limits after every Claude response. When a limit is
exceeded it writes the reset timestamp to `~/.claude/limit_reset_at`. The
`claude-watch` wrapper reads that file on exit, sleeps until the reset time,
and runs `claude --resume` to pick up the session.

## Requirements

- macOS
- Claude Code CLI
- Google Chrome with a `claude.ai` tab open
- Chrome setting enabled: **View → Developer → Allow JavaScript from Apple Events**

## Install

```sh
git clone https://github.com/RandomGUID/claude-quota
cd claude-quota
./install.sh
```

Then add `~/bin` to your PATH if it isn't already:

```sh
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

Run `claude-watch` instead of `claude`, from whichever worktree directory you
want Claude to work in:

```sh
cd ~/projects/my-worktree
claude-watch
```

Multiple instances work independently — each one pauses and resumes on its own.
They share the same usage pool, so whichever hits the limit first will cause the
others to stop at the end of their current response too.

## Files installed

| File | Purpose |
|---|---|
| `~/bin/claude-probe` | Probes usage via Chrome AppleScript |
| `~/bin/claude-watch` | Wrapper that resumes after limit resets |
| `~/.claude/hooks/stop.sh` | Global Stop hook wired into all Claude Code sessions |

The Stop hook is registered in `~/.claude/settings.json`. `install.sh` merges
it non-destructively — existing hooks are preserved.

## Caveats

- Chrome must be running with a `claude.ai` tab open while Claude works overnight.
  If it isn't, `claude-probe` fails open (assumes not limited) so Claude keeps working.
- The VS Code Claude extension is unaffected — Stop hooks only fire for Claude Code CLI.
- Monthly extra-usage cap is not checked. Set a cap in claude.ai settings if needed.
