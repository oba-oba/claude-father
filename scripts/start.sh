#!/bin/zsh
# usage: start.sh [-d workdir] [-c telegram,imessage,discord] [-s tmux-session-name] [-r]
#        -r: respawn window 0 of the existing session in place (self-update)
set -e

DIR="$PWD"
CHANNELS=""
SESSION="claude-father"
RESPAWN=""
while getopts "d:c:s:r" opt; do
  case $opt in
    d) DIR="$OPTARG";;
    c) CHANNELS="$OPTARG";;
    s) SESSION="$OPTARG";;
    r) RESPAWN=1;;
    *) exit 1;;
  esac
done

export PATH="$HOME/.bun/bin:$PATH"

TOKEN_FILE="$HOME/.claude/channels/telegram/token"
if [ -f "$TOKEN_FILE" ]; then
  export "$(cat "$TOKEN_FILE")"
fi

for cmd in claude tmux; do
  command -v "$cmd" >/dev/null || { echo "$cmd not found — see README prerequisites"; exit 1; }
done

installed=$(claude plugin list 2>/dev/null)
if [ -z "$CHANNELS" ]; then
  [ -f "$TOKEN_FILE" ] || [ -f "${TOKEN_FILE:h}/.env" ] || [ -n "$TELEGRAM_BOT_TOKEN" ] && CHANNELS="telegram"
  for ch in imessage discord; do
    if echo "$installed" | grep -q "$ch@claude-plugins-official"; then
      CHANNELS="$CHANNELS,$ch"
    fi
  done
  CHANNELS="${CHANNELS#,}"
fi

if [ -z "$CHANNELS" ]; then
  echo "No channel plugins installed. Install at least one:"
  echo "  claude plugin install telegram@claude-plugins-official"
  echo "  claude plugin install imessage@claude-plugins-official"
  exit 1
fi

if [[ "$CHANNELS" == *imessage* && "$OSTYPE" == darwin* ]]; then
  if ! sqlite3 "$HOME/Library/Messages/chat.db" "select 1" >/dev/null 2>&1; then
    case "$TERM_PROGRAM" in
      Apple_Terminal) APP="Terminal";;
      iTerm.app) APP="iTerm";;
      *) APP="${TERM_PROGRAM:-the app this terminal runs in}";;
    esac
    echo "The iMessage channel needs Full Disk Access, and macOS won't prompt for it."
    echo "Opening System Settings → Privacy & Security → Full Disk Access now."
    echo
    echo "  1. Click '+', add '$APP', and turn its toggle ON"
    echo "  2. Quit $APP completely (Cmd-Q) and reopen it"
    echo "  3. Run this script again"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    exit 1
  fi
fi

FLAGS=""
for ch in ${(s:,:)CHANNELS}; do
  if [ "$ch" = "telegram" ]; then
    FLAGS="$FLAGS --dangerously-load-development-channels plugin:claude-father@claude-father"
  else
    FLAGS="$FLAGS --channels plugin:$ch@claude-plugins-official"
  fi
done

LAUNCH="TELEGRAM_FORCE_POLL=1 claude 'Invoke the claude-father skill and follow it as your operating instructions for this session.' --settings '{\"channelsEnabled\":true,\"crossSessionInbound\":\"accept\"}'$FLAGS"

if [ -n "$RESPAWN" ]; then
  tmux respawn-window -k -t "$SESSION:0" "cd \"$DIR\" && $LAUNCH"
  echo "Claude Father respawned in $DIR (channels: $CHANNELS)."
  exit 0
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

mkdir -p "$HOME/.claude/father"
tmux new-session -d -s "$SESSION" -c "$DIR" "$LAUNCH"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$HOME/.claude/father/topics.json" ]; then
  "$SCRIPT_DIR/topics_sync.sh" >/dev/null 2>&1 &
fi

if [[ "$CHANNELS" == *telegram* ]] && ! tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -q '^watchdog$'; then
  tmux new-window -d -t "$SESSION" -n watchdog "bash '$SCRIPT_DIR/watchdog.sh' '$SESSION' '$DIR'"
fi

echo "Claude Father started in $DIR (channels: $CHANNELS)."
echo "Attach with: tmux attach -t $SESSION"
