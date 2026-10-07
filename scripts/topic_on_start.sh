#!/bin/bash
# SessionStart(startup) hook: waits in the background until the new chat gets a title,
# then creates its Telegram forum topic and records it in topics.json. Exits after that.
DIR="$(cd "$(dirname "$0")" && pwd)"
MAP="$HOME/.claude/father/topics.json"
[ -f "$MAP" ] || exit 0
input=$(cat)
SID=$(echo "$input" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
CWD=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$SID" ] && [ -n "$TRANSCRIPT" ] || exit 0

watch() {
  local title tid
  for _ in $(seq 90); do
    sleep 10
    jq -e --arg s "$SID" '.topics[$s]' "$MAP" >/dev/null 2>&1 && return
    [ -f "$TRANSCRIPT" ] || continue
    head -c 20000 "$TRANSCRIPT" | grep -q 'Invoke the claude-father skill' && return
    title=$(grep -o '"customTitle":"[^"]*"' "$TRANSCRIPT" | tail -1 | cut -d'"' -f4)
    [ -n "$title" ] || title=$(grep -o '"aiTitle":"[^"]*"' "$TRANSCRIPT" | tail -1 | cut -d'"' -f4)
    [ -n "$title" ] || continue
    jq -e --arg t "$title" '(.ignore_titles // []) | index($t)' "$MAP" >/dev/null && return
    tid=$(bash "$DIR/topics.sh" create "$(jq -r .group "$MAP")" "$title") || return
    tmp=$(mktemp) && jq --indent 1 --arg s "$SID" --argjson t "$tid" --arg n "$title" --arg c "$CWD" \
      '.topics[$s] = {topic: $t, title: $n, cwd: $c}' "$MAP" > "$tmp" && mv "$tmp" "$MAP"
    echo "$(date '+%F %T') topic $tid: $title ($SID)" >> "$HOME/.claude/father/topic_on_start.log"
    return
  done
}

watch </dev/null >/dev/null 2>>"$HOME/.claude/father/topic_on_start.log" &
disown
exit 0
