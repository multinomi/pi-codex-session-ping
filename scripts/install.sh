#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_bin="${INSTALL_BIN:-$HOME/.local/bin}"
systemd_user_dir="${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}"
provider="${PI_PROVIDER:-openai-codex}"
model="${PI_MODEL:-gpt-5.5}"
thinking="${PI_THINKING:-off}"
times_csv="${PING_TIMES:-06:59,12:00,17:01,22:02}"

mkdir -p "$install_bin" "$systemd_user_dir"
install -m 0755 "$repo_root/bin/pi-codex-session-ping" "$install_bin/pi-codex-session-ping"
install -m 0755 "$repo_root/bin/pi-ping-now" "$install_bin/pi-ping-now"

cat > "$systemd_user_dir/pi-codex-session-ping.service" <<SERVICE
[Unit]
Description=Pi lightweight Codex session cadence ping
Documentation=https://pi.dev

[Service]
Type=oneshot
Environment=PI_PROVIDER=$provider
Environment=PI_MODEL=$model
Environment=PI_THINKING=$thinking
ExecStart=$install_bin/pi-codex-session-ping
WorkingDirectory=$HOME
StandardOutput=journal
StandardError=journal
SERVICE

IFS=',' read -r -a times <<< "$times_csv"
timer_units=()
for time in "${times[@]}"; do
  hour="${time%%:*}"
  minute="${time##*:}"
  unit="pi-codex-session-ping-${hour}-${minute}.timer"
  timer_units+=("$unit")
  cat > "$systemd_user_dir/$unit" <<TIMER
[Unit]
Description=Pi Codex session cadence ping at $hour:$minute

[Timer]
OnCalendar=*-*-* $hour:$minute:00
Persistent=true
RandomizedDelaySec=0
AccuracySec=1min
Unit=pi-codex-session-ping.service

[Install]
WantedBy=timers.target
TIMER
done

systemctl --user daemon-reload
systemctl --user enable --now "${timer_units[@]}"

printf 'Installed %s\n' "$install_bin/pi-codex-session-ping"
printf 'Installed %s\n' "$install_bin/pi-ping-now"
printf 'Enabled timers: %s\n' "${timer_units[*]}"
systemctl --user list-timers 'pi-codex-session-ping*' --all --no-pager
