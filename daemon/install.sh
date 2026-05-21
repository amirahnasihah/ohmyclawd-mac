#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="ohmyclawd-daemon"

# Linux requires root; macOS runs as current user
if [[ "${OS}" == "Linux" ]]; then
  if [[ "${EUID}" -ne 0 ]]; then
    echo "install.sh must run as root (sudo) on Linux" >&2
    exit 1
  fi
  TARGET_USER="${OHMYCLAWD_USER:-${SUDO_USER:-}}"
  if [[ -z "${TARGET_USER}" ]]; then
    echo "Set OHMYCLAWD_USER=<user who runs claude code> or invoke via sudo." >&2
    exit 1
  fi
  if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
    echo "user '${TARGET_USER}' does not exist" >&2
    exit 1
  fi
else
  TARGET_USER="${USER}"
fi

cd "$(dirname "$0")"

echo "==> building ohmyclawd-daemon..."
go build -trimpath -ldflags='-s -w' -o ohmyclawd-daemon .
install -m 0755 ohmyclawd-daemon "${INSTALL_DIR}/ohmyclawd-daemon"

if [[ "${OS}" == "Darwin" ]]; then
  PLIST_DIR="${HOME}/Library/LaunchAgents"
  PLIST_FILE="${PLIST_DIR}/local.${SERVICE_NAME}.plist"
  mkdir -p "${PLIST_DIR}"

  echo "==> installing launchd agent..."
  sed "s|__HOME__|${HOME}|g" launchd/local.ohmyclawd-daemon.plist > "${PLIST_FILE}"

  launchctl unload "${PLIST_FILE}" 2>/dev/null || true
  launchctl load "${PLIST_FILE}"

  echo "==> done! ohmyclawd-daemon is running"
  echo ""
  echo "logs:  tail -f /tmp/ohmyclawd-daemon.log"
  echo "usage: curl http://localhost:8787/usage"
  echo ""
  echo "to stop:    launchctl unload ${PLIST_FILE}"
  echo "to restart: launchctl unload ${PLIST_FILE} && launchctl load ${PLIST_FILE}"

else
  echo "==> installing systemd service for user '${TARGET_USER}'..."
  sed "s|__USER__|${TARGET_USER}|g" systemd/ohmyclawd-daemon.service \
    > /etc/systemd/system/${SERVICE_NAME}.service

  systemctl daemon-reload
  systemctl enable ${SERVICE_NAME}.service
  systemctl restart ${SERVICE_NAME}.service
  systemctl --no-pager status ${SERVICE_NAME}.service | head -10
fi
