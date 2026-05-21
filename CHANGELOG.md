# Changelog

All notable changes to this fork are documented here.

This fork ([amirahnasihah/ohmyclawd-mac](https://github.com/amirahnasihah/ohmyclawd-mac)) targets macOS users. For the original Linux-focused project, see [opariffazman/ohmyclawd](https://github.com/opariffazman/ohmyclawd).

---

## [0.5.1] — 2026-05-22

### macOS Support

- **launchd autostart** — `daemon/install.sh` now detects OS; macOS uses a launchd plist template (`daemon/launchd/local.ohmyclawd-daemon.plist`) instead of systemd. No `sudo` required on macOS.
- **OAuth token auth** — On macOS, Claude Code stores credentials in the Keychain (no `.credentials.json` file). The daemon now supports `CLAUDE_CODE_OAUTH_TOKEN` env var, generated via `claude setup-token`.
- **README rewritten** — Full macOS setup guide A-Z: OAuth token, static IP, captive portal, launchd commands, and common pitfalls (no `.local`, unset token from shell).

### Firmware

- **OTA URL** — Updated from upstream repo to this fork (`amirahnasihah/ohmyclawd-mac`) so OTA checks and downloads releases from the correct source.
- **Info screen credits** — `BY: amirahnasihah`, `GH: ohmyclawd-mac`, `OG: opariffazman` (original author credit preserved).
- **Upload port** — Fixed `platformio.ini` upload port to `/dev/cu.usbserial-10` (macOS).

### CI/CD

- **Branch** — `daemon.yml` trigger updated from `master` → `main`.
- **Action versions** — Updated to current stable: `checkout@v4`, `setup-go@v5`, `setup-python@v5`, `cache@v4`, `upload-artifact@v4`, `download-artifact@v4`.

### Repo

- **Default branch** — Renamed `master` → `main`.
- **install.sh** — REPO reference and curl URL updated to point to this fork.

---

## Differences from upstream

| | [opariffazman/ohmyclawd](https://github.com/opariffazman/ohmyclawd) | [amirahnasihah/ohmyclawd-mac](https://github.com/amirahnasihah/ohmyclawd-mac) |
|--|--|--|
| Primary OS | Linux | macOS + Linux |
| Service manager | systemd | launchd (macOS) / systemd (Linux) |
| Auth method | `~/.claude/.credentials.json` | macOS Keychain via `claude setup-token` |
| Install privileges | sudo required | No sudo on macOS |
| OTA source | upstream releases | fork releases |
| Default branch | `master` | `main` |
| GitHub Actions versions | outdated (v6–v8) | current stable (v4–v5) |
| README | Linux-focused quick start | macOS A-Z setup guide |
