# Agent Instructions

Use these instructions when installing or adapting this repository on behalf of a user.

## Goal

Install a low-context Pi ping job that can replace heavyweight Codex Desktop ping automations. The job should:

- run Pi non-interactively
- avoid sessions, tools, extensions, skills, prompt templates, themes, and context files
- set reasoning/thinking off
- log token usage
- use the user's chosen provider/model
- schedule recurring pings with the local platform scheduler

## Do Not

- Do not copy private auth files into this repo.
- Do not commit machine-specific absolute paths unless they are examples.
- Do not assume `openai-codex` is available; verify `pi --list-models`.
- Do not use `--system-prompt ''`; Pi may fall back to its default coding-agent system prompt.
- Do not enable both the old Codex Desktop automation and this scheduler without telling the user.

## Discovery

Check Pi:

```bash
command -v pi
pi --version
pi --list-models gpt-5.4-mini
```

Check the minimal command before scheduling:

```bash
PI_PROVIDER=openai-codex PI_MODEL=gpt-5.4-mini ./bin/pi-codex-session-ping
```

Expected output:

```text
pong
usage provider=... model=... api=... input=... output=... total=... cost_usd=...
```

Check that `provider` and `model` match the intended values. The wrapper logs the actual values Pi reports in the final response, so this catches provider/model fallback.

## Linux

Prefer systemd user timers. Install with:

```bash
./scripts/install.sh
```

If user timers cannot connect to the bus from the current shell, export:

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
```

Then retry.

## macOS

Install the wrapper to `~/.local/bin/pi-codex-session-ping`.

Use `launchd/com.pi-codex-session-ping.plist` as a template. Replace `YOUR_USER`, copy it to `~/Library/LaunchAgents/`, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.pi-codex-session-ping.plist
```

For exact daily wall-clock times, create one plist per time with `StartCalendarInterval`.

## WSL

Prefer the Linux systemd path if `/etc/wsl.conf` has systemd enabled.

If not, install the wrapper and use cron:

```cron
59 6 * * * ~/.local/bin/pi-codex-session-ping
0 12 * * * ~/.local/bin/pi-codex-session-ping
1 17 * * * ~/.local/bin/pi-codex-session-ping
2 22 * * * ~/.local/bin/pi-codex-session-ping
```

## Verification

Linux:

```bash
systemctl --user list-timers 'pi-codex-session-ping*' --all --no-pager
systemctl --user start pi-codex-session-ping.service
journalctl --user -u pi-codex-session-ping.service -n 50 --no-pager
tail -n 20 ~/.local/state/pi-codex-session-ping/history.tsv
```

macOS:

```bash
launchctl list | grep pi-codex-session-ping
tail -n 50 ~/Library/Logs/pi-codex-session-ping.log
tail -n 20 ~/.local/state/pi-codex-session-ping/history.tsv
```
