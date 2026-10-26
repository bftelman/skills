#!/usr/bin/env bash
# Launch/ensure Chrome (or Chromium) with a CDP debug port so the Playwright MCP can attach to
# Microsoft Teams. Cross-platform (macOS/Linux). NON-INTERACTIVE — the teams skill runs it directly.
# Windows users: use teams-chrome.ps1 instead.
#
# Uses a DEDICATED profile (never touches your main browser). First launch you log into Teams once;
# the session persists. Binds IPv4 127.0.0.1 to match a --cdp-endpoint http://127.0.0.1:<port>.
#
# Usage: teams-chrome.sh [PORT]   (default 9222)
set -euo pipefail
PORT="${1:-9222}"

# Already up? nothing to do.
if curl -fsS -m 1 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "CDP already up on http://127.0.0.1:${PORT}"; exit 0
fi

find_browser() {
  local c
  case "$(uname -s)" in
    Darwin)
      for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
               "/Applications/Chromium.app/Contents/MacOS/Chromium" \
               "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
        [ -x "$c" ] && { echo "$c"; return; }
      done ;;
    *)
      for c in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge; do
        command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
      done ;;
  esac
  return 1
}

BROWSER="$(find_browser || true)"
[ -z "${BROWSER:-}" ] && { echo "ERROR: Chrome/Chromium not found. Install it or edit this script." >&2; exit 1; }

case "$(uname -s)" in
  Darwin) PROFILE="$HOME/Library/Application Support/ClaudeTeamsChrome" ;;
  *)      PROFILE="${XDG_CONFIG_HOME:-$HOME/.config}/ClaudeTeamsChrome" ;;
esac
mkdir -p "$PROFILE"

"$BROWSER" \
  --remote-debugging-port="$PORT" \
  --remote-debugging-address=127.0.0.1 \
  --user-data-dir="$PROFILE" \
  --no-first-run --no-default-browser-check \
  "https://teams.cloud.microsoft/v2/" >/dev/null 2>&1 &

for _ in $(seq 1 30); do
  if curl -fsS -m 1 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
    echo "CDP up on http://127.0.0.1:${PORT} (profile: dedicated)"; exit 0
  fi
  sleep 0.5
done
echo "Launched browser but CDP not confirmed on ${PORT} yet; give it a moment."
exit 0
