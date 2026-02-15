#!/usr/bin/env bash
# Claude Code hook script for AnyGif-Claude-Pet.
# Reads hook event JSON from stdin, writes to ~/.claude-pet/ for the pet app to consume.
# Must exit 0 always and run fast (< 100ms).

set -euo pipefail

PET_DIR="$HOME/.claude-pet"
CURRENT_EVENT="$PET_DIR/current-event.json"
EVENTS_LOG="$PET_DIR/events.jsonl"

# Ensure directory exists.
mkdir -p "$PET_DIR"

# Read stdin and extract fields using python3 (available on all macOS).
python3 -c "
import sys, json, time, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

event = data.get('event', data.get('hook_event_name', ''))
tool = data.get('tool_name', data.get('tool', None))
session_id = data.get('session_id', None)
ts = time.time()

out = {
    'event': event,
    'tool': tool,
    'timestamp': ts,
    'sessionId': session_id,
}

# Write current event (atomic: write tmp then rename).
tmp = '$CURRENT_EVENT' + '.tmp'
with open(tmp, 'w') as f:
    json.dump(out, f)
os.rename(tmp, '$CURRENT_EVENT')

# Append to daily log.
with open('$EVENTS_LOG', 'a') as f:
    f.write(json.dumps(out) + '\n')
" || true

exit 0
