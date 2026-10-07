#!/bin/bash
# usage: topics_sync.sh [group_chat_id]
# Creates one forum topic per known chat; idempotent. Mapping: ~/.claude/father/topics.json
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
MAP="$HOME/.claude/father/topics.json"
mkdir -p "$HOME/.claude/father"
GROUP="${1:-$(python3 -c "import json;print(json.load(open('$MAP'))['group'])" 2>/dev/null)}"
[ -n "$GROUP" ] || { echo "no topics group configured — run: topics_sync.sh <group_chat_id>" >&2; exit 1; }
[ -f "$MAP" ] || printf '{"group": "%s", "max_age_days": 7, "topics": {}}\n' "$GROUP" > "$MAP"

MAX_AGE_DAYS=$(python3 -c "import json;print(json.load(open('$MAP')).get('max_age_days',7))" 2>/dev/null || echo 7)
CUTOFF=$(( $(date +%s) - MAX_AGE_DAYS * 86400 ))

"$DIR/list_chats.sh" 50 | while IFS='|' read -r ts state title sid cwd; do
  ts=$(echo "$ts" | xargs); sid=$(echo "$sid" | xargs); title=$(echo "$title" | xargs); cwd=$(echo "$cwd" | xargs)
  [ -n "$sid" ] || continue
  [ "$title" = "<untitled>" ] && continue
  te=$(date -j -f '%Y-%m-%d %H:%M' "$ts" +%s 2>/dev/null || date -d "$ts" +%s 2>/dev/null || echo 0)
  [ "$te" -ge "$CUTOFF" ] || continue
  python3 - "$title" <<PYEOF 2>/dev/null && continue
import json, sys
sys.exit(0 if sys.argv[1] in json.load(open("$MAP")).get("ignore_titles", []) else 1)
PYEOF
  known=$(python3 -c "import json;print(json.load(open('$MAP'))['topics'].get('$sid',{}).get('topic',''))" 2>/dev/null)
  [ -n "$known" ] && continue
  tid=$("$DIR/topics.sh" create "$GROUP" "$title") || { echo "could not create topic for '$title' (Telegram error above)" >&2; continue; }
  python3 - "$sid" "$tid" "$title" "$cwd" <<PYEOF
import json, sys
d = json.load(open("$MAP"))
d["topics"][sys.argv[1]] = {"topic": int(sys.argv[2]), "title": sys.argv[3], "cwd": sys.argv[4]}
json.dump(d, open("$MAP", "w"), indent=1)
PYEOF
  echo "created topic $tid: $title"
  sleep 1
done
