# Claude Father

One always-on Claude Code session ("father") you control from **Telegram** and/or **iMessage**. From one chat you can:

- start multiple tasks that run in parallel on your machine
- get status of everything that's running
- list your chats by freshness — live and dormant — and revive any of them
- focus on one chat and keep working with it from your phone, then switch to another
- **use a Telegram forum group as your session browser** — one Topic per coding chat, type in a Topic to talk to that session
- spawn new sessions (tmux windows or headless) for bigger tasks
- approve tool-permission prompts from your phone (inline Allow/Deny buttons)

Built entirely on official Claude Code features: [channels](https://code.claude.com/docs/en/channels) (Telegram/iMessage plugins), cross-session messaging (ListAgents/SendMessage), and background agents. This plugin adds the orchestrator skill, a chat-listing script, and a launcher.

## Install

No clone needed — install as a plugin, then let Claude set itself up:

```sh
claude plugin marketplace add CreepteedLTD/claude-father
claude plugin install claude-father@claude-father
```

Then start any `claude` session and run:

```
/claude-father:setup
```

Claude walks you through the rest interactively: installs anything missing (tmux, Bun, the channel plugins), asks which channels you want, prompts for your Telegram bot token, checks macOS Full Disk Access for iMessage, enables cross-session messaging, and launches Claude Father. Later, `/claude-father:start` relaunches it anytime. The only steps Claude can't do for you:

- **Telegram**: create the bot yourself — [@BotFather](https://t.me/BotFather) → `/newbot` → paste the token when the script asks. After launch, DM the bot once and approve the pairing code it gives you (`/claude-father:access pair <code>` in Claude Father session), then `/claude-father:access policy allowlist`.
- **iMessage (macOS)**: if Full Disk Access is missing, the script opens the right System Settings pane — add your terminal, reopen it, re-run. After launch, iMessage yourself and click OK on the one "control Messages" popup.

Re-running `/claude-father:setup` is safe — it skips whatever is already done.

> **First launch shows one confirmation**: the Telegram channel ships inside this plugin (a fork of the official one), and Claude Code asks you to confirm loading a non-official channel. If the bot seems silent right after setup: `tmux attach -t claude-father`, press **Enter** on the "local channel development" dialog, detach with `Ctrl-b d`. Once per machine.

## Topics — a Telegram group as your session browser (optional, recommended)

1. Create a new Telegram group → group settings → enable **Topics** → add your bot → promote it to **admin** with *Manage Topics*.
2. In @BotFather: `/setprivacy` → your bot → **Disable** (then remove + re-add the bot to the group — Telegram quirk; re-grant admin).
3. Copy any message link from the group (long-press a message → Copy Message Link) and send it to your bot in DM: "this is my topics group: <link>".

The bot allowlists the group, creates one Topic per recent coding chat, and from then on: **type in a Topic → that session answers in the same Topic**. General topic = talk to Claude Father itself. Only chats active in the last 7 days get Topics — tell the bot "include chats up to a month" to widen it, or ask it to prune Topics you don't want.

New chats get their Topic automatically: a `SessionStart` hook shipped with the plugin waits for the chat's title (set after the first reply) and creates the Topic. Chats whose titles are listed in `ignore_titles` in `~/.claude/father/topics.json` never get a Topic — handy for recurring scheduled chats.

## Run / restart later

`/claude-father:start` in any session — or directly:

```sh
<plugin dir>/scripts/start.sh -d ~/work        # -d = directory Claude Father works from
```

Flags: `-d workdir` (default: current dir), `-c telegram,imessage` (default: every installed channel plugin), `-s tmux-session-name` (default: `claude-father`).

Starts (or re-attaches to) a detached tmux session. Attach any time with `tmux attach -t claude-father`; detach with `Ctrl-b d`. (If you prefer shell over skills: clone the repo and run `scripts/setup.sh` / `scripts/start.sh` — same result.)

## Use — message your bot (or yourself on iMessage)

- `/chats` (or "show my latest chats") → numbered, freshness-sorted list of your chats, live and dormant
- reply with just a number → switch to that chat, reviving it with full context if it's offline
- while focused, every message you send relays to that chat (a 👀 reaction confirms the forward; the answer comes back as the only reply)
- `/back` (or "back to you") → stop relaying, talk to Claude Father again
- `/status` → summary of everything running
- "run the tests in project X and fix failures" → spawns a background task
- "tell the session working on the parser to also update the docs" → one-off relay
- "update yourself" → the bot updates its own plugin and restarts
- every received message gets an instant 👀 reaction — your "it's working" signal; a watchdog auto-heals the bot connection if it's ever lost

**Telegram menu (optional, recommended):** in [@BotFather](https://t.me/BotFather) run `/setcommands`, pick your bot, paste:

```
chats - List my latest chats (reply a number to switch)
status - What's running right now
back - Stop relaying, talk to Claude Father
```

The ☰ menu button then appears in the bot chat — tap `/chats`, type a digit, and you've switched sessions.

## Limits

- Claude Father cannot answer **permission prompts** in spawned sessions — it tells you which tmux window to attach to.
- Cross-session messages are plain text; Claude Father steers other sessions by messaging them, not by driving their tools.
- Claude Father must stay running (the tmux session) for chat to reach it.
- "Enable cross-session messaging" in setup sets `crossSessionInbound: "accept"` — your sessions auto-deliver messages from your *own* other local sessions without a desktop approval click. Decline it if you prefer approving each relay manually.
- **Org-managed accounts** (claude.ai Team/Enterprise): channels are admin-gated — the session reports "blocked by org policy" and messages are dropped. Setup detects this and offers the fixes: a machine-admin `managed-settings.json` with `channelsEnabled: true`, an org-admin toggle in claude.ai admin settings, or using a personal account. Personal Pro/Max accounts are unaffected.

## Manual setup (reference)

Everything `setup.sh` automates, if you'd rather do it by hand: Claude Code ≥ 2.1.232 (`claude update`); `brew install tmux`; `curl -fsSL https://bun.sh/install | bash`; `claude plugin marketplace add ./claude-father && claude plugin install claude-father@claude-father` (the Telegram channel is built in — a fork of the official plugin with forum-topics routing; iMessage needs `claude plugin install imessage@claude-plugins-official`); Telegram token into `~/.claude/channels/telegram/token` as `TELEGRAM_BOT_TOKEN=<token>` (or `/claude-father:configure <token>` in a session); then `scripts/start.sh` (it passes the required settings per-session).
