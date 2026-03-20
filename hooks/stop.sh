#!/bin/sh
# Global Stop hook: detects usage limits and signals claude-watch to pause.
#
# Fires after every Claude response. When a limit is exceeded, writes the
# resume timestamp to ~/.claude/limit_reset_at so claude-watch knows to
# wait rather than exit permanently.
#
# Does not force autonomous looping — that's left to each project's own
# Stop hook or CLAUDE.md instructions. This hook only handles limit detection.

set -e

PROBE="${HOME}/bin/claude-probe"
LIMIT_FILE="${HOME}/.claude/limit_reset_at"

input=$(cat)

# stop_hook_active=true means a previous hook invocation already returned
# "block" this turn — exit cleanly to prevent an infinite loop.
if printf '%s' "$input" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('stop_hook_active') else 1)" \
    2>/dev/null; then
    exit 0
fi

# Probe limits. If exceeded, record the reset time for claude-watch.
probe_out=$("$PROBE" 2>/dev/null)
if [ $? -eq 1 ]; then
    resume_at=$(printf '%s' "$probe_out" | python3 -c \
        "import json,sys; d=json.load(sys.stdin); print(d.get('resume_at',''))" 2>/dev/null)
    if [ -n "$resume_at" ]; then
        printf '%s' "$resume_at" > "$LIMIT_FILE"
    fi
    printf '[claude-watch] Usage limit reached (resume at %s). Stopping.\n' "$resume_at" >&2
fi

exit 0
