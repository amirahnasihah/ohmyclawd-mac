#!/usr/bin/env bash
set -euo pipefail

# OhMyClawd daemon installer
# Usage: curl -fsSL https://raw.githubusercontent.com/amirahnasihah/ohmyclawd-mac/main/install.sh | sudo bash
# macOS: curl -fsSL https://raw.githubusercontent.com/amirahnasihah/ohmyclawd-mac/main/install.sh | bash

REPO="amirahnasihah/ohmyclawd-mac"
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="ohmyclawd-daemon"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
  Linux)
    case "${ARCH}" in
      x86_64) BINARY="ohmyclawd-daemon-linux-amd64" ;;
      aarch64) BINARY="ohmyclawd-daemon-linux-arm64" ;;
      *) echo "error: unsupported arch ${ARCH}" >&2; exit 1 ;;
    esac
    ;;
  Darwin)
    case "${ARCH}" in
      x86_64) BINARY="ohmyclawd-daemon-darwin-amd64" ;;
      arm64) BINARY="ohmyclawd-daemon-darwin-arm64" ;;
      *) echo "error: unsupported arch ${ARCH}" >&2; exit 1 ;;
    esac
    ;;
  *) echo "error: unsupported OS ${OS}" >&2; exit 1 ;;
esac

if [[ "${OS}" == "Linux" ]] && [[ "${EUID}" -ne 0 ]]; then
  echo "error: must run as root (sudo) on Linux" >&2
  exit 1
fi

if [[ "${OS}" == "Linux" ]]; then
  TARGET_USER="${OHMYCLAWD_USER:-${SUDO_USER:-}}"
  if [[ -z "${TARGET_USER}" ]]; then
    echo "error: set OHMYCLAWD_USER=<user who runs claude code> or invoke via sudo" >&2
    exit 1
  fi
  if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
    echo "error: user '${TARGET_USER}' does not exist" >&2
    exit 1
  fi
else
  TARGET_USER="${USER}"
fi

echo "==> fetching latest release..."
DOWNLOAD_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep "browser_download_url.*${BINARY}" \
  | cut -d '"' -f 4)

if [[ -z "${DOWNLOAD_URL}" ]]; then
  echo "error: could not find ${BINARY} in latest release" >&2
  exit 1
fi

echo "==> downloading ${DOWNLOAD_URL}..."
curl -fsSL -o "/tmp/${BINARY}" "${DOWNLOAD_URL}"
install -m 0755 "/tmp/${BINARY}" "${INSTALL_DIR}/ohmyclawd-daemon"
rm -f "/tmp/${BINARY}"

if [[ "${OS}" == "Darwin" ]]; then
  PLIST_DIR="${HOME}/Library/LaunchAgents"
  PLIST_FILE="${PLIST_DIR}/local.${SERVICE_NAME}.plist"
  mkdir -p "${PLIST_DIR}"

  echo "==> installing launchd agent for user '${TARGET_USER}'..."
  cat > "${PLIST_FILE}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.${SERVICE_NAME}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${INSTALL_DIR}/ohmyclawd-daemon</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>OHMYCLAWD_LISTEN</key>
    <string>:8787</string>
    <key>OHMYCLAWD_PROBE_INTERVAL</key>
    <string>60s</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/ohmyclawd-daemon.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/ohmyclawd-daemon.log</string>
</dict>
</plist>
EOF

  launchctl unload "${PLIST_FILE}" 2>/dev/null || true
  launchctl load "${PLIST_FILE}"

  echo "==> done! ohmyclawd-daemon is running"
  echo ""
  echo "logs: tail -f /tmp/ohmyclawd-daemon.log"
  echo "usage: curl http://$(hostname).local:8787/usage"

else
  echo "==> installing systemd service for user '${TARGET_USER}'..."
  cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=ohmyclawd daemon — probes Anthropic for Claude Code utilization
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/ohmyclawd-daemon
Restart=always
RestartSec=5
User=${TARGET_USER}
Group=${TARGET_USER}
Environment=OHMYCLAWD_LISTEN=:8787
Environment=OHMYCLAWD_PROBE_INTERVAL=60s
NoNewPrivileges=true
PrivateTmp=false
ProtectSystem=strict
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ${SERVICE_NAME}.service
  systemctl restart ${SERVICE_NAME}.service

  echo "==> done! ohmyclawd-daemon is running"
  systemctl --no-pager status ${SERVICE_NAME}.service | head -5
  echo ""
  echo "usage: curl http://$(hostname).local:8787/usage"
fi
