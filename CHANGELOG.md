# Changelog

All notable changes to this fork are documented here.

This fork ([amirahnasihah/ohmyclawd-mac](https://github.com/amirahnasihah/ohmyclawd-mac)) targets macOS users. For the original Linux-focused project, see [opariffazman/ohmyclawd](https://github.com/opariffazman/ohmyclawd).

---

## [0.7.2] — 2026-06-17

### Reliability

- **Always-on Fly.io daemon** — `min_machines_running = 1`, `auto_stop = off`. No more cold start delays when ESP32 reconnects.
- **On-demand probe** — daemon triggers an immediate Anthropic API probe on first `/usage` hit if state is empty, so ESP32 gets real data within seconds of a fresh deploy or restart.
- **ESP32 HTTP timeout** — 5-second timeout on usage fetch prevents hanging on network blips.
- **Fast retry on failure** — ESP32 retries every 5 seconds when fetch fails (was 30s). Normal 30-second poll on success.
- **Pinned ESP32 platform** — locked `espressif32@~6.9.0` to fix WiFiManager build breakage on newer framework versions.

---

## [0.5.3] — 2026-06-09

### Cloud Deployment

- **Fly.io support** — daemon can now be deployed to Fly.io (`fly deploy`). No more static IP issues — ESP32 points to a stable `https://ohmyclawd-daemon.fly.dev` URL.
- **Dockerfile** — multi-stage build (`golang:latest` → `alpine`), `CGO_ENABLED=0` for fully static binary, image size ~6MB.
- **fly.toml** — pre-configured for `sin` (Singapore) region, 256MB shared CPU, auto-stop when idle.
- **ESP32 daemon URL** — update captive portal to `https://ohmyclawd-daemon.fly.dev` after cloud deploy. No more local IP dependency.

---

## [0.5.2] — 2026-05-22

### macOS Support

- **launchd install no sudo** — daemon now installs to `~/.local/bin` instead of `/usr/local/bin` on macOS, so `./install.sh` runs without `sudo`.
- **OAuth token prompt** — `install.sh` now prompts for the OAuth token interactively during install instead of requiring it to be pre-set in the environment.
- **Auto binary path in plist** — launchd plist uses `__INSTALL_DIR__` placeholder, resolved to the correct path at install time.

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
| Cloud deploy | not supported | Fly.io (`fly deploy`) with Dockerfile + fly.toml |
| Daemon URL | local IP only | local IP or `https://<app>.fly.dev` |
