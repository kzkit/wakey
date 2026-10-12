# Shared helpers for scripts/release-direct.sh and scripts/release-appstore.sh.
# Sourced, not executed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_ROOT/Wakey.xcodeproj"
VERSION_CONFIG="$REPO_ROOT/Config/Version.xcconfig"
TEAM_ID="C5JDGZ56JV"
# One DerivedData for all release builds, so Sparkle's tools land at a known path
# and package resolution is cached between releases.
DERIVED_DATA="$REPO_ROOT/build/DerivedData"

bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; reset=$'\033[0m'

step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$reset"; }
ok() { printf '%s✓%s %s\n' "$green" "$reset" "$*"; }
die() { printf '%serror:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

confirm() {
    local answer
    read -r -p "$1 [y/N] " answer
    [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]
}

read_setting() {
    local value
    value=$(sed -nE "s/^$1 = (.+)$/\1/p" "$VERSION_CONFIG")
    [[ -n "$value" ]] || die "$1 not found in $VERSION_CONFIG"
    echo "$value"
}

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

# Runs xcodebuild with its output in a log file, showing the errors if it fails.
run_xcodebuild() {
    local log="$1"; shift
    if ! xcodebuild "$@" >"$log" 2>&1; then
        grep -E "error:|\*\* .* FAILED \*\*" "$log" | head -30 >&2 || true
        die "xcodebuild failed, full log: $log"
    fi
}

# archive_app SCHEME CONFIGURATION ARCHIVE_PATH LOG
archive_app() {
    run_xcodebuild "$4" archive \
        -project "$PROJECT" \
        -scheme "$1" \
        -configuration "$2" \
        -destination "generic/platform=macOS" \
        -archivePath "$3" \
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates
}

# Checks the archived app carries the version from Config/Version.xcconfig.
check_archive_version() {
    local info="$1/Products/Applications/Wakey.app/Contents/Info.plist"
    local archived_version archived_build
    archived_version=$(plist_value "$info" CFBundleShortVersionString)
    archived_build=$(plist_value "$info" CFBundleVersion)
    [[ "$archived_version" == "$2" && "$archived_build" == "$3" ]] ||
        die "archive is $archived_version ($archived_build), expected $2 ($3)"
    ok "archived Wakey $archived_version ($archived_build)"
}
