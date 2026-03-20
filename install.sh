#!/bin/sh
# Installs claude-quota tools and wires up the global Stop hook.
#
# By default installs executables to ~/bin. Override with CLAUDE_QUOTA_BIN:
#   CLAUDE_QUOTA_BIN=/usr/local/bin ./install.sh
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${CLAUDE_QUOTA_BIN:-$HOME/bin}"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

mkdir -p "$BIN_DIR" "$HOOKS_DIR"

# Install executables
cp "$REPO_DIR/bin/claude-probe" "$BIN_DIR/claude-probe"
cp "$REPO_DIR/bin/claude-watch" "$BIN_DIR/claude-watch"
chmod +x "$BIN_DIR/claude-probe" "$BIN_DIR/claude-watch"

# Install Stop hook
cp "$REPO_DIR/hooks/stop.sh" "$HOOKS_DIR/stop.sh"
chmod +x "$HOOKS_DIR/stop.sh"

# Wire Stop hook into ~/.claude/settings.json non-destructively.
# If the file doesn't exist, create a minimal one.
# If it exists but has no Stop hook entry for stop.sh, add it.
if [ ! -f "$SETTINGS" ]; then
    cat > "$SETTINGS" << EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOOKS_DIR/stop.sh"
          }
        ]
      }
    ]
  }
}
EOF
    echo "Created $SETTINGS"
else
    if python3 -c "
import json, sys
with open('$SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {}).get('Stop', [])
entries = [e for h in hooks for e in h.get('hooks', [])]
exists = any('stop.sh' in e.get('command', '') for e in entries)
sys.exit(0 if exists else 1)
" 2>/dev/null; then
        echo "Stop hook already present in $SETTINGS — skipping"
    else
        python3 << PYEOF
import json

path = '$SETTINGS'
hook_entry = {
    "hooks": [{"type": "command", "command": "$HOOKS_DIR/stop.sh"}]
}

with open(path) as f:
    d = json.load(f)

d.setdefault('hooks', {}).setdefault('Stop', []).append(hook_entry)

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')

print('Added Stop hook to $SETTINGS')
PYEOF
    fi
fi

# Check whether BIN_DIR is on PATH
case ":$PATH:" in
    *":$BIN_DIR:"*) on_path=1 ;;
    *)              on_path=0 ;;
esac

echo ""
echo "claude-quota installed to $BIN_DIR."
echo ""
if [ "$on_path" -eq 0 ]; then
    echo "  $BIN_DIR is not on your PATH. Add it:"
    echo "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc"
    echo ""
fi
echo "  Enable Chrome AppleScript access (one-time):"
echo "    Chrome → View → Developer → Allow JavaScript from Apple Events"
echo ""
echo "  Verify setup:"
echo "    claude-probe --check"
