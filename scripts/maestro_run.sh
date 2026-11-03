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
PBXPROJ="${ROOT}/WorkoutTracker.xcodeproj/project.pbxproj"
DERIVED="${ROOT}/.derivedData/maestro"
WATCH_DETACHED=0

restore_watch_embed() {
  if [[ "${WATCH_DETACHED}" -eq 1 ]]; then
    echo "→ Restoring Watch embed in project.pbxproj"
    git -C "${ROOT}" checkout -- "${PBXPROJ}" 2>/dev/null || true
    WATCH_DETACHED=0
  fi
}
trap restore_watch_embed EXIT

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

# No watchOS Simulator runtime → temporarily drop Watch embed (same as prior audit passes).
if ! xcrun simctl list runtimes 2>/dev/null | grep -qiE 'watchOS|watchos'; then
  if grep -q 'ACF4FCAD2F01698F00850F6E /\* Embed Watch Content \*/' "${PBXPROJ}" \
    && grep -q 'AC3CB9922F8176AB008A6777 /\* PBXTargetDependency \*/' "${PBXPROJ}"; then
    echo "→ No watchsimulator runtime; detaching Watch embed for iOS Maestro build"
    python3 - <<'PY'
from pathlib import Path
path = Path("WorkoutTracker.xcodeproj/project.pbxproj")
text = path.read_text()
text = text.replace("\t\t\t\tACF4FCAD2F01698F00850F6E /* Embed Watch Content */,\n", "")
text = text.replace("\t\t\t\tAC3CB9922F8176AB008A6777 /* PBXTargetDependency */,\n", "")
path.write_text(text)
PY
    WATCH_DETACHED=1
  fi
fi

echo "→ Building ${SCHEME} for ${SIM_ID}"
mkdir -p "${DERIVED}"
xcodebuild \
  -scheme "${SCHEME}" \
  -destination "id=${SIM_ID}" \
  -configuration Debug \
  -derivedDataPath "${DERIVED}" \
  -quiet \
  build

APP="${DERIVED}/Build/Products/Debug-iphonesimulator/WorkoutTracker.app"
if [[ ! -d "${APP}" ]]; then
  echo "WorkoutTracker.app not found at ${APP}"
  exit 1
fi
if ! /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP}/Info.plist" >/dev/null 2>&1; then
  echo "Built app missing CFBundleIdentifier at ${APP}"
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
