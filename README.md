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
