#!/bin/sh
# Global Stop hook: detects usage limits and signals claude-watch to pause.
#
# Fires after every Claude response. When a limit is exceeded, writes the
# resume timestamp to ~/.claude/limit_reset_at so claude-watch knows to
# wait rather than exit permanently.
#
# Does not force autonomous looping — that's left to each project's own
# Stop hook or CLAUDE.md task instructions. This hook only handles limit
# detection.
#
# Environment:
#   CLAUDE_QUOTA_ON_PROBE_FAILURE=stop|continue (default: stop)
#     Controls behaviour when Chrome is unreachable. See claude-probe --check.

set -e

PROBE="${HOME}/bin/claude-probe"
LIMIT_FILE="${HOME}/.claude/limit_reset_at"
FAIL_MODE="${CLAUDE_QUOTA_ON_PROBE_FAILURE:-stop}"

input=$(cat)

# stop_hook_active=true means a previous hook invocation already returned
# "block" this turn — exit cleanly to prevent an infinite loop.
if printf '%s' "$input" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('stop_hook_active') else 1)" \
    2>/dev/null; then
    exit 0
fi

# When running claude -p (print/non-interactive mode), Claude outputs only the
# FINAL assistant turn to stdout. Without blocking, the stop hook causes a second
# turn where Claude narrates "the stop hook ran cleanly" — swallowing the actual
# response (e.g. a code review ending with VERDICT: PASS).
#
# Set CLAUDE_QUOTA_BLOCK_FOLLOW_UP=1 in any context where you run claude -p and
# want the real response to be the sole stdout output (e.g. CI pipelines).
if [ "${CLAUDE_QUOTA_BLOCK_FOLLOW_UP:-}" = "1" ]; then
    printf '{"decision":"block"}'
    exit 0
fi

# Probe limits. --cached uses an adaptive interval so the 3-second AppleScript
# call doesn't fire after every response — only when the cache is stale.
probe_out=$("$PROBE" --cached 2>/dev/null)
probe_code=$?

if [ "$probe_code" -eq 1 ]; then
    # Limit exceeded — record reset time for claude-watch
    resume_at=$(printf '%s' "$probe_out" | python3 -c \
        "import json,sys; d=json.load(sys.stdin); print(d.get('resume_at',''))" 2>/dev/null)
    if [ -n "$resume_at" ]; then
        printf '%s' "$resume_at" > "$LIMIT_FILE"
    fi
    printf '[claude-quota] Usage limit reached (resume at %s).\n' "$resume_at" >&2

elif [ "$probe_code" -eq 2 ] && [ "$FAIL_MODE" = "stop" ]; then
    # Probe failed and fail mode is stop — treat as limited without a known reset time.
    # claude-watch will fall back to a 1-hour wait.
    printf '[claude-quota] Probe failed (Chrome unreachable?). Pausing (CLAUDE_QUOTA_ON_PROBE_FAILURE=stop).\n' >&2
    touch "$LIMIT_FILE"
fi

exit 0
