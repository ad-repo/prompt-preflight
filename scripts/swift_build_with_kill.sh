#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXECUTABLE_NAME="${APP_EXECUTABLE_NAME:-PromptPreflight}"

# Keep compiler/cache artifacts local to the workspace for predictable builds.
export SWIFTPM_ENABLE_GLOBAL_CACHES=0
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT_DIR/.build/clang-module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

echo "==> Checking for running '${APP_EXECUTABLE_NAME}' processes"
if pgrep -x "$APP_EXECUTABLE_NAME" >/dev/null 2>&1; then
  echo "==> Stopping running '${APP_EXECUTABLE_NAME}' instances"
  pkill -x "$APP_EXECUTABLE_NAME" || true
  # Give macOS a moment to tear down the process before rebuilding.
  sleep 1
else
  echo "==> No running '${APP_EXECUTABLE_NAME}' process found"
fi

echo "==> Running swift build $*"
swift build --package-path "$ROOT_DIR" "$@"
