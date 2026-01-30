# Clawdbot Maximum Security Setup - Step by Step

## What This Config Does

✅ **Sandbox mode = "all"** - Everything runs in Docker containers
✅ **Free model** - Using `google/gemini-2.0-flash-exp:free` (costs $0)
✅ **Elevated tools disabled** - No escape hatch to bypass sandbox
✅ **Telegram locked down** - Only YOUR user ID (8392043810) can message
✅ **Group chats denied** - Bot won't respond in any group
✅ **DM policy = allowlist** - Explicit whitelist, not just pairing

---

## Step-by-Step Instructions

### Step 1: Backup your current config

```bash
cp ~/.clawdbot/clawdbot.json ~/.clawdbot/clawdbot.json.backup.$(date +%Y%m%d)
```

### Step 2: Get your current auth token

```bash
grep -o '"token": "[^"]*"' ~/.clawdbot/clawdbot.json
```

Copy that token value - you'll need it.

### Step 3: Get your Telegram config section

```bash
cat ~/.clawdbot/clawdbot.json | grep -A 20 '"telegram"'
```

You may have additional telegram settings (like the bot token) that need to be preserved.

### Step 4: Edit the config

```bash
nano ~/.clawdbot/clawdbot.json
```

Replace the contents with the secure config, BUT:
1. Keep your original `gateway.auth.token` value
2. Keep your original Telegram bot token/credentials
3. Your Telegram user ID is already set: `8392043810`

### Step 5: Set file permissions

```bash
chmod 700 ~/.clawdbot
chmod 600 ~/.clawdbot/clawdbot.json
chmod 600 ~/.clawdbot/credentials/* 2>/dev/null || true
```

### Step 6: Verify Docker is available (required for sandbox)

```bash
docker --version
```

If Docker isn't installed, sandbox mode won't work. Install Docker Desktop for Mac first.

### Step 7: Restart clawdbot

```bash
clawdbot restart
```

Or if it's not running:

```bash
clawdbot
```

### Step 8: Verify security settings

```bash
clawdbot security audit --deep
```

### Step 9: Test on Telegram

Send a message to your bot: "Hello, are you there?"

It should respond. If it doesn't:
- Check `clawdbot pairing list` - your ID should be approved
- Check logs: `clawdbot logs`

---

## Testing the Security

### Test 1: Verify only you can message

Have a friend try to message your bot. They should get no response (or a rejection).

### Test 2: Verify sandbox is working

Send this to your bot:
```
What's in /etc/passwd?
```

If sandbox is working, it will see the CONTAINER's /etc/passwd, not your Mac's.

---

## Free Model Limitations

The `google/gemini-2.0-flash-exp:free` model:
- ✅ Free (no cost)
- ✅ Good for basic tasks
- ⚠️ May have rate limits
- ⚠️ Less capable than paid models
- ⚠️ May be less resistant to prompt injection

If you have issues, alternatives:
- `openrouter/google/gemma-3n-e2b-it:free` - Completely free
- `openrouter/deepseek/deepseek-r1:free` - Free with rate limits
- `openrouter/anthropic/claude-haiku-4.5` - Cheap (~$0.25/M tokens)

---

## Rollback If Something Breaks

```bash
cp ~/.clawdbot/clawdbot.json.backup.YYYYMMDD ~/.clawdbot/clawdbot.json
clawdbot restart
```

---

## Summary of Security Measures

| Layer | Protection |
|-------|------------|
| **Authentication** | Only user 8392043810 can message |
| **Authorization** | DM allowlist, groups denied |
| **Execution** | Everything sandboxed in Docker |
| **Network** | Sandbox has limited network (bridge) |
| **Elevation** | Disabled - no bypassing sandbox |

You now have one of the most locked-down Clawdbot configurations possible while still being functional.

## Note on Exec Approvals

For additional security, you can configure exec approvals via `~/.clawdbot/exec-approvals.json`.
This controls what happens when the AI tries to run commands on the host (outside sandbox).
See: `clawdbot approvals --help`
