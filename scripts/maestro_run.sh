#!/usr/bin/env bash
# Build, install, and run Maestro flows for WorkoutTracker.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Homebrew OpenJDK (Maestro needs a JRE; avoid system /usr/bin/java stub)
if [[ -z "${JAVA_HOME:-}" ]]; then
  if [[ -d /opt/homebrew/opt/openjdk@17 ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
  elif [[ -d /opt/homebrew/opt/openjdk ]]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk"
  fi
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi
export PATH="${HOME}/.maestro/bin:${PATH}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${1:-smoke}"
BUNDLE_ID="com.borisdev.WorkoutTracker"
SCHEME="WorkoutTracker"

if ! command -v maestro >/dev/null 2>&1; then
  echo "Maestro CLI not found. Install: curl -Ls 'https://get.maestro.mobile.dev' | bash"
  exit 1
fi

# Prefer booted sim; else iPhone 17 / 17 Pro
SIM_ID="$(xcrun simctl list devices booted | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p' | head -1 || true)"
if [[ -z "${SIM_ID}" ]]; then
  SIM_ID="$(xcrun simctl list devices available | grep -E 'iPhone 17( Pro)? \(' | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')"
  if [[ -n "${SIM_ID}" ]]; then
    xcrun simctl boot "${SIM_ID}" || true
    xcrun simctl bootstatus "${SIM_ID}" -b
  fi
fi
if [[ -z "${SIM_ID}" ]]; then
  echo "No iOS Simulator available."
  exit 1
fi

echo "→ Building ${SCHEME} for ${SIM_ID}"
xcodebuild \
  -scheme "${SCHEME}" \
  -destination "id=${SIM_ID}" \
  -configuration Debug \
  -quiet \
  build

APP="$(find ~/Library/Developer/Xcode/DerivedData -path '*/Build/Products/Debug-iphonesimulator/WorkoutTracker.app' -type d 2>/dev/null | head -1)"
if [[ -z "${APP}" || ! -d "${APP}" ]]; then
  echo "WorkoutTracker.app not found in DerivedData"
  exit 1
fi

echo "→ Installing ${APP}"
xcrun simctl uninstall "${SIM_ID}" "${BUNDLE_ID}" 2>/dev/null || true
xcrun simctl install "${SIM_ID}" "${APP}"

mkdir -p .maestro/output
echo "→ maestro test (tag=${TAG})"
set +e
if [[ "${TAG}" == "all" ]]; then
  # Run every flow under .maestro/flows (smoke + workout + …)
  maestro test .maestro/flows --output .maestro/output
else
  maestro test .maestro/flows --include-tags="${TAG}" --output .maestro/output
fi
STATUS=$?
set -e
if [[ "${STATUS}" -ne 0 ]]; then
  echo "✗ Maestro ${TAG} failed (exit ${STATUS})"
  exit "${STATUS}"
fi
echo "✓ Maestro ${TAG} passed"
