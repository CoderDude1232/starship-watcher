#!/bin/zsh
# Bumps the build number, archives a Release build and uploads it to TestFlight.
# Commits the bump locally on success; push it / open a PR yourself.
#
#   scripts/testflight.sh          # next build number (current + 1)
#   scripts/testflight.sh 20       # explicit build number
#   DRY_RUN=1 scripts/testflight.sh  # bump + archive only, then restore the project file
#
# Needs Xcode signed in to an account on team HK396F3767 (Settings > Accounts).
set -euo pipefail

cd "${0:A:h}/.."

PROJECT="Starship Watcher.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
SCHEME="Starship Watcher"
BUILD_DIR="build"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree not clean. Commit or stash first." >&2
  exit 1
fi

# App and widget must share one build number; refuse to guess if they've drifted.
current=($(grep -o 'CURRENT_PROJECT_VERSION = [0-9]*;' "$PBXPROJ" | grep -o '[0-9]*' | sort -u))
if (( ${#current} != 1 )); then
  echo "Targets have different build numbers: ${current[*]}" >&2
  exit 1
fi
next=${1:-$(( current[1] + 1 ))}
if (( next <= current[1] )); then
  echo "Build $next must be greater than current $current[1]." >&2
  exit 1
fi

restore() { git checkout -- "$PBXPROJ"; }
trap 'echo "Failed. Restoring $PBXPROJ." >&2; restore' ERR

echo "Build $current[1] -> $next ($(git rev-parse --short HEAD) on $(git branch --show-current))"
sed -i '' "s/CURRENT_PROJECT_VERSION = $current[1];/CURRENT_PROJECT_VERSION = $next;/" "$PBXPROJ"

archive="$BUILD_DIR/StarshipWatcher-$next.xcarchive"
rm -rf "$archive" "$BUILD_DIR/export-$next"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  -allowProvisioningUpdates -quiet archive

if [[ -n "${DRY_RUN:-}" ]]; then
  trap - ERR
  restore
  echo "Dry run: archived $archive, skipped upload, project file restored."
  exit 0
fi

xcodebuild -exportArchive -archivePath "$archive" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$BUILD_DIR/export-$next" -allowProvisioningUpdates

trap - ERR
git commit -q -m "Build number $next (TestFlight)" -- "$PBXPROJ"
echo "Uploaded build $next. Committed bump locally; push it / open a PR."
