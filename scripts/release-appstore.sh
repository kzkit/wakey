#!/bin/bash
# Archives the App Store build of Wakey and uploads it to App Store Connect.
#
#   scripts/release-appstore.sh              archive, then ask before uploading
#   scripts/release-appstore.sh --no-upload  archive and export a signed .pkg locally only
#
# The version comes from Config/Version.xcconfig (change it with scripts/bump.sh).
# Artifacts go to release/<version>/appstore/.
#
# Uploading only sends the build to App Store Connect for processing; it still has to be
# added to a version and submitted for review there. The upload signs in with the Apple
# account in Xcode's Accounts settings, or with an App Store Connect API key when
# WAKEY_ASC_KEY_PATH, WAKEY_ASC_KEY_ID and WAKEY_ASC_ISSUER_ID are set.
set -euo pipefail
source "$(dirname "$0")/release-common.sh"

upload=1
for arg in "$@"; do
    case "$arg" in
        --no-upload) upload=0 ;;
        -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option $arg" ;;
    esac
done

version=$(read_setting MARKETING_VERSION)
build_number=$(read_build_number)
out="$REPO_ROOT/release/$version/appstore"

auth_args=()
if [[ -n "${WAKEY_ASC_KEY_PATH:-}" ]]; then
    auth_args=(-authenticationKeyPath "$WAKEY_ASC_KEY_PATH"
        -authenticationKeyID "${WAKEY_ASC_KEY_ID:?set WAKEY_ASC_KEY_ID too}"
        -authenticationKeyIssuerID "${WAKEY_ASC_ISSUER_ID:?set WAKEY_ASC_ISSUER_ID too}")
fi

export_archive() {
    local destination="$1"
    cat >"$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>destination</key><string>$destination</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF
    run_xcodebuild "$out/export-$destination.log" -exportArchive \
        -archivePath "$out/Wakey.xcarchive" \
        -exportOptionsPlist "$out/ExportOptions.plist" \
        -exportPath "$out/export" \
        -allowProvisioningUpdates ${auth_args[@]+"${auth_args[@]}"}
}

# An upload uses up its build number, so only upload what's on origin/main.
if ((upload)); then
    check_clean_main
fi

rm -rf "$out"
mkdir -p "$out"

step "Archiving Wakey App Store $version ($build_number)"
archive_app "Wakey App Store" "Release-AppStore" "$out/Wakey.xcarchive" "$out/archive.log"
check_archive_version "$out/Wakey.xcarchive" "$version" "$build_number"

if ! ((upload)); then
    step "Exporting a signed package"
    export_archive export
    ok "exported to $out/export"
    exit 0
fi

step "Ready to upload $version ($build_number) to App Store Connect"
if ! confirm "Upload?"; then
    echo "Not uploaded. The archive is at $out/Wakey.xcarchive"
    exit 0
fi
export_archive upload
ok "uploaded $version ($build_number); it shows up in App Store Connect once processing finishes"
