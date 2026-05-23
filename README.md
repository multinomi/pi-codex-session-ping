# Pi Codex Session Ping

Tiny scheduled pings through [Pi](https://pi.dev) for people who want to keep a Codex/OpenAI session cadence warm without launching a full Codex Desktop automation job.

This is not an official OpenAI or Pi project. It is a small wrapper around Pi's non-interactive mode.

## Why

Codex Desktop automations are convenient, but even a prompt like `ping` can load the full Codex agent context. Pi can run a much smaller harness:

- no saved session
- no tools
- no extensions
- no skills
- no prompt templates
- no context files
- no themes
- reasoning/thinking off
- compact JSON output parsed into token logs

In one local test, the optimized Pi command used about 40 input tokens instead of about 390. Exact usage depends on provider, model, Pi version, and platform.

## Example Token Costs

These numbers are from one Linux desktop setup using `gpt-5.4-mini` and a one-word `pong` response. Treat them as a practical sanity check, not a benchmark.

| Path | What ran | Observed usage |
| --- | --- | ---: |
| Codex Desktop automation | A scheduled Codex automation with `prompt = "ping"`, `reasoning_effort = "none"` | Not directly logged in the same format, but it invokes the Codex automation runner and loads the Codex agent context. |
| Codex CLI | `codex exec --ephemeral --ignore-user-config --ignore-rules --skip-git-repo-check ... 'Reply with exactly: pong'` | `23,870` tokens |
| Pi, default fallback prompt | Pi with tools/skills/context disabled, but `--system-prompt ''` | about `393-402` total tokens |
| Pi, minimal custom prompt | Pi with tools/skills/context disabled and `--system-prompt 'x'` | about `42-51` total tokens |

The important discovery was that `--system-prompt ''` is not the same as "no prompt" in Pi. It can fall back to Pi's default coding-agent prompt, which adds a few hundred tokens. Passing a tiny non-empty system prompt, such as `x`, forces the custom-prompt path and avoids that default harness text.

The local optimized systemd run logged:

```text
pong
usage provider=openai-codex model=gpt-5.4-mini api=openai-codex-responses input=37 output=5 cache_read=0 cache_write=0 total=42 cost_usd=0.00005025
```

The goal is not to make the request free. The goal is to make the scheduled cadence ping pay only for the smallest useful model call instead of loading a full coding-agent context.

## Requirements

- [Pi Coding Agent](https://pi.dev)
- A Pi-authenticated provider/model, for example `openai-codex` with `gpt-5.4-mini`
- Node.js available on `PATH`
- One scheduler:
  - Linux: systemd user timers
  - macOS: launchd
  - WSL: systemd user timers if enabled, otherwise cron

## Quick Start

Clone and install:

```bash
git clone https://github.com/multinomi/pi-codex-session-ping.git
cd pi-codex-session-ping
./scripts/install.sh
```

The default schedule mirrors a roughly 5-hour cadence:

- `06:59`
- `12:00`
- `17:01`
- `22:02`

The default command uses:

```bash
pi --provider openai-codex --model gpt-5.4-mini --thinking off
```

Override at install time:

```bash
PI_PROVIDER=openai \
PI_MODEL=gpt-5.4-mini \
PING_TIMES=06:59,12:00,17:01,22:02 \
./scripts/install.sh
```

## Logs

Execution logs:

```bash
journalctl --user -u pi-codex-session-ping.service -n 50 --no-pager
```

Token history:

```bash
tail -n 20 ~/.local/state/pi-codex-session-ping/history.tsv
```

Expected output:

```text
pong
usage provider=openai-codex model=gpt-5.4-mini api=openai-codex-responses input=37 output=5 cache_read=0 cache_write=0 total=42 cost_usd=0.00005025
```

The history file records the actual provider/model/API reported by Pi on the final response, not just the configured defaults:

```text
timestamp provider model api input_tokens output_tokens cache_read_tokens cache_write_tokens total_tokens cost_usd
```

## How It Works

The installed wrapper runs:

```bash
pi \
  --print \
  --mode json \
  --no-session \
  --no-tools \
  --no-extensions \
  --no-skills \
  --no-prompt-templates \
  --no-themes \
  --no-context-files \
  --offline \
  --provider "$PI_PROVIDER" \
  --model "$PI_MODEL" \
  --thinking off \
  --system-prompt 'x' \
  'Reply with exactly: pong'
```

The tiny non-empty system prompt is intentional. In Pi, an empty system prompt can fall back to the default coding-agent system prompt. A tiny non-empty prompt forces the custom-prompt path and keeps the request small.

Pi emits JSON events in `--mode json`; the wrapper parses the final `turn_end` event and appends the actual provider, model, API, and usage to `~/.local/state/pi-codex-session-ping/history.tsv`.

## Platform Notes

### Linux

Use systemd user timers:

```bash
./scripts/install.sh
systemctl --user list-timers 'pi-codex-session-ping*' --all --no-pager
```

If user timers should run while you are logged out:

```bash
loginctl enable-linger "$USER"
```

### macOS

Use the LaunchAgent template in [launchd/com.pi-codex-session-ping.plist](launchd/com.pi-codex-session-ping.plist).

Copy it to:

```bash
~/Library/LaunchAgents/com.pi-codex-session-ping.plist
```

Edit paths, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.pi-codex-session-ping.plist
```

macOS launchd calendar schedules are verbose, so the provided template uses a 5-hour interval. For exact wall-clock times, create four LaunchAgents with separate `StartCalendarInterval` entries.

### WSL

If your WSL distro has systemd enabled, use the Linux installer.

Check:

```bash
systemctl --user status
```

If systemd is not enabled, use cron:

```cron
59 6 * * * ~/.local/bin/pi-codex-session-ping
0 12 * * * ~/.local/bin/pi-codex-session-ping
1 17 * * * ~/.local/bin/pi-codex-session-ping
2 22 * * * ~/.local/bin/pi-codex-session-ping
```

## Agent Instructions

For assistants or coding agents packaging this setup on another machine, see [docs/agent-instructions.md](docs/agent-instructions.md).

## Uninstall

Linux systemd user timers:

```bash
systemctl --user disable --now 'pi-codex-session-ping-*.timer'
rm -f ~/.config/systemd/user/pi-codex-session-ping.service
rm -f ~/.config/systemd/user/pi-codex-session-ping-*.timer
systemctl --user daemon-reload
```

Wrapper and logs:

```bash
rm -f ~/.local/bin/pi-codex-session-ping
rm -rf ~/.local/state/pi-codex-session-ping
```
