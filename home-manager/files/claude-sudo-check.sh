#!/usr/bin/env sh

# Claude Code PreToolUse hook for Bash commands.
# Blocks sudo commands when credentials aren't cached.
# First attempt: denies immediately with a message.
# Subsequent attempts: polls for up to 30s for credentials.

STATEFILE="/tmp/claude-sudo-hook-notified"
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

# Only check commands that contain sudo
if ! printf '%s' "$COMMAND" | grep -qw 'sudo'; then
  exit 0
fi

# Test if sudo credentials are cached
if sudo -n true 2>/dev/null; then
  rm -f "$STATEFILE"
  exit 0
fi

# First time: deny with message so it's visible in the terminal
if [ ! -f "$STATEFILE" ]; then
  touch "$STATEFILE"
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Sudo credentials not cached. Please run sudo -v in another terminal. Retrying automatically..."}}'
  exit 0
fi

# Subsequent attempts: poll for up to 30s
ELAPSED=0
while ! sudo -n true 2>/dev/null; do
  sleep 1
  ELAPSED=$((ELAPSED + 1))
  if [ "$ELAPSED" -ge 30 ]; then
    rm -f "$STATEFILE"
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Sudo credentials not cached. Timed out after 30s. Please run sudo -v in another terminal and retry."}}'
    exit 0
  fi
done

rm -f "$STATEFILE"
exit 0
