# Design

## The problem

Claude Code has two rolling usage limits that are shared across all running
instances (CLI terminals, not the VS Code extension):

- **5-hour limit** — resets on a fixed UTC schedule
- **Weekly limit** — resets once per week

When either limit is exceeded, Claude Code continues working but charges
pay-as-you-go extra credits. For unattended overnight runs this is a liability:
a Claude instance can burn through extra credits for hours before anyone notices.

## Why not just query the API?

The obvious approach — curl the usage endpoint with the stored OAuth token — is
blocked by Cloudflare. The `claude.ai` domain uses managed Cloudflare protection
that fingerprints TLS sessions. Curl and Python's `urllib` present different TLS
fingerprints than Chrome, triggering a 403 challenge regardless of whether the
auth credentials are valid.

## The AppleScript approach

Instead of faking a browser, we use the real one. Chrome exposes a JavaScript
execution interface to AppleScript via the `execute javascript` command. We find
any background `claude.ai` tab and run a `fetch()` call from inside it — same
session, same cookies, same TLS fingerprint. Cloudflare never sees a non-browser
client.

The tab does not need to be active or visible. Chrome does not switch windows or
tabs. From the user's perspective, nothing happens.

**Two-step pattern:** AppleScript's `execute javascript` is synchronous but
`fetch()` is async. Returning a Promise from the script returns a useless object.
Instead:
1. The script fires `fetch()` and stores the result in `localStorage`.
2. AppleScript waits 3 seconds, then reads the value back as a plain string.

## Exit codes

`claude-probe` uses three distinct exit codes so callers can handle each case
differently:

| Code | Meaning |
|------|---------|
| 0 | Within limits |
| 1 | One or more limits exceeded |
| 2 | Probe failed (Chrome unavailable, no tab, API error) |

## Fail-closed by default

When the probe fails (exit 2), `claude-watch` and `stop.sh` consult
`CLAUDE_QUOTA_ON_PROBE_FAILURE`:

- **`stop`** (default) — treat as limited, pause Claude. Safe: if Chrome closes
  at 3am you don't silently burn credits until morning.
- **`continue`** — treat as within limits, keep going. Useful if you're confident
  Chrome stays open and don't want occasional AppleScript hiccups to interrupt work.

This is a deliberate tradeoff. The default protects your wallet at the cost of
potentially pausing unnecessarily. Set `continue` explicitly if you accept that
risk.

## Flag file coordination

When the Stop hook detects a limit mid-session, it writes the reset timestamp
to `~/.claude/limit_reset_at`. `claude-watch` checks this file on exit to
distinguish a limit-caused stop from a normal task completion — if the file
exists, it sleeps until the reset time and then runs `claude --resume`. If the
file is absent, `claude-watch` exits normally.

Multiple instances share the same flag file. Whichever instance's Stop hook
fires first writes the reset time; the others pick it up on their next exit.

## Adaptive probe caching

The Stop hook fires after every Claude response. A fresh AppleScript probe takes
~3 seconds (the async fetch + delay). At low utilization, probing on every
response would add ~10% overhead for no real benefit.

`claude-probe --cached` reads `~/.claude/quota_cache.json` and only runs a fresh
probe when the cached result is stale. The staleness threshold adapts to how
close you are to the limit:

The two limits are tracked separately because they move at very different speeds.
The five-hour limit can ramp quickly within an active session. The weekly limit
climbs slowly over 7 days — a high weekly number late in the week shouldn't slow
down that day's work.

**Five-hour limit:**

| Utilization | Check interval |
|---|---|
| < 80% | 30 minutes |
| 80–90% | 5 minutes |
| 90–95% | 2 minutes |
| ≥ 95% | 30 seconds |

**Weekly limit:**

| Utilization | Check interval |
|---|---|
| < 95% | 30 minutes |
| 95–98% | 5 minutes |
| ≥ 98% | 2 minutes |

The effective interval is `min(five_hour_interval, seven_day_interval)`. At 83%
weekly with a fresh five-hour window, the interval stays at 30 minutes. If you
want tighter guarantees, adjust the thresholds in `cache_interval()`.

`claude-watch` always uses a fresh probe (no `--cached`) since it only runs once
on Claude exit, where an accurate reading matters.

## What this does not cover

- **Monthly extra-usage cap** (`extra_usage` in the API response) — this is a
  billing ceiling, not a time-based limit that resets. Manage it in claude.ai
  account settings.
- **VS Code Claude extension** — Stop hooks only fire for Claude Code CLI
  processes. The extension is unaffected.
- **Other browsers** — the AppleScript is Chrome-specific. Safari and Firefox
  have different AppleScript interfaces; contributions welcome.
