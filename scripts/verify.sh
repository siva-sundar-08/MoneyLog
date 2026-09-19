#!/bin/zsh
# Builds MoneyLog and runs unit + UI tests on the newest available iPhone simulator.
# Usage: ./scripts/verify.sh [build|test]   (default: test)
set -euo pipefail
cd "$(dirname "$0")/.."
ACTION="${1:-test}"
SIM=$(xcrun simctl list devices available | grep -E "^\s+iPhone" | tail -1 | sed -E 's/^ *(.*) \(([0-9A-F-]+)\).*/\2/')
echo "Simulator: $SIM"
LOG=build/verify-$ACTION.log
mkdir -p build
set +e
xcodebuild -project MoneyLog.xcodeproj -scheme MoneyLog \
  -destination "id=$SIM" -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO "$ACTION" > "$LOG" 2>&1
STATUS=$?
set -e
grep -E "error:|warning: .*(MoneyLog/|MoneyLogTests/)|\*\* (BUILD|TEST)|Test run with|✘|failed" "$LOG" | sort -u | head -80 > build/verify-summary.txt
cat build/verify-summary.txt
echo "exit=$STATUS" | tee -a build/verify-summary.txt
exit $STATUS
