#!/bin/bash
# Post a one-line system/ops message to the Slack #system-messages channel.
# Zero-token (hermes send uses the bot token directly; no gateway needed).
# Usage: system_notify.sh "message"   — exits 0 even on failure so callers
# (backup scripts, hooks) never die because a notification couldn't send.
CHANNEL=$(grep '^SYSTEM_NOTIFY_CHANNEL=' "$HOME/.hermes/.env" | tail -1 | cut -d= -f2)
[ -z "$CHANNEL" ] && exit 0
"$HOME/.local/bin/hermes" send -t "slack:$CHANNEL" "$1" >/dev/null 2>&1 || true
exit 0
