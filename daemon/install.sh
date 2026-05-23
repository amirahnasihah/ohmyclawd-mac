#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
SERVICE_NAME="ohmyclawd-daemon"

# macOS installs to ~/.local/bin (no sudo); Linux installs to /usr/local/bin (sudo required)
if [[ "${OS}" == "Darwin" ]]; then
  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "${INSTALL_DIR}"
else
  INSTALL_DIR="/usr/local/bin"
fi

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

  # Get OAuth token
  OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
  if [[ -z "${OAUTH_TOKEN}" ]]; then
    echo ""
    echo "==> Claude OAuth token required."
    echo "    Generate one with: claude setup-token"
    echo "    Or set CLAUDE_CODE_OAUTH_TOKEN env var before running this script."
    echo ""
    read -r -s -p "Paste token (hidden): " OAUTH_TOKEN
    echo ""
  fi
  if [[ -z "${OAUTH_TOKEN}" ]]; then
    echo "error: token cannot be empty" >&2
    exit 1
  fi

  echo "==> installing launchd agent..."
  sed -e "s|__HOME__|${HOME}|g" \
      -e "s|__OAUTH_TOKEN__|${OAUTH_TOKEN}|g" \
      -e "s|__INSTALL_DIR__|${INSTALL_DIR}|g" \
      launchd/local.ohmyclawd-daemon.plist > "${PLIST_FILE}"

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
