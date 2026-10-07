#!/bin/bash
# usage: topics.sh create <chat_id> <name>       → prints new topic id
#        topics.sh rename <chat_id> <topic_id> <name>
#        topics.sh close  <chat_id> <topic_id>
#        topics.sh send   <chat_id> <topic_id> <text>
set -e
STATE="$HOME/.claude/channels/telegram"
TOKEN="${TELEGRAM_BOT_TOKEN:-$(cut -d= -f2 "$STATE/token" 2>/dev/null || true)}"
[ -n "$TOKEN" ] || TOKEN="$(grep '^TELEGRAM_BOT_TOKEN=' "$STATE/.env" 2>/dev/null | cut -d= -f2 || true)"
[ -n "$TOKEN" ] || { echo "no bot token" >&2; exit 1; }
API="https://api.telegram.org/bot$TOKEN"

case "$1" in
  create)
    for attempt in 1 2 3; do
      res=$(curl -s "$API/createForumTopic" -d chat_id="$2" --data-urlencode name="$3")
      tid=$(echo "$res" | grep -o '"message_thread_id":[0-9]*' | cut -d: -f2 || true)
      [ -n "$tid" ] && { echo "$tid"; exit 0; }
      wait=$(echo "$res" | grep -o '"retry_after":[0-9]*' | cut -d: -f2 || true)
      [ -n "$wait" ] || { echo "$res" >&2; exit 1; }
      sleep $((wait + 1))
    done
    exit 1 ;;
  rename)
    curl -sf "$API/editForumTopic" -d chat_id="$2" -d message_thread_id="$3" --data-urlencode name="$4" >/dev/null && echo ok ;;
  close)
    curl -sf "$API/closeForumTopic" -d chat_id="$2" -d message_thread_id="$3" >/dev/null && echo ok ;;
  send)
    curl -sf "$API/sendMessage" -d chat_id="$2" -d message_thread_id="$3" --data-urlencode text="$4" | grep -o '"message_id":[0-9]*' | head -1 | cut -d: -f2 ;;
  *)
    echo "usage: topics.sh create|rename|close|send ..." >&2; exit 1 ;;
esac
