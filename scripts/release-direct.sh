#!/bin/bash
# Builds, signs, notarizes and publishes the direct-download (Sparkle) build of Wakey.
#
#   scripts/release-direct.sh                     build everything, then ask before publishing
#   scripts/release-direct.sh --no-publish        build, notarize and sign only
#   scripts/release-direct.sh --publish-only      publish what a previous run left in release/<version>/
#   scripts/release-direct.sh --notes-file FILE   use FILE as the GitHub release notes
#
# The version comes from Config/Version.xcconfig (change it with scripts/bump.sh).
# Artifacts go to release/<version>/: the archive, the notarized and stapled Wakey.app,
# wakey-<version>.zip, the new appcast.xml, notes.md, and the xcodebuild logs.
#
# Publishing creates the GitHub release v<version> with the zip attached, then commits
# appcast.xml and pushes it to main, which is when Sparkle clients start seeing the update.
#
# Needs: the notarytool keychain profile (WAKEY_NOTARY_PROFILE, default wakey-notary),
# the Sparkle EdDSA private key in the login keychain, and gh signed in to GitHub.
set -euo pipefail
source "$(dirname "$0")/release-common.sh"

GITHUB_REPO="kzkit/wakey"
NOTARY_PROFILE="${WAKEY_NOTARY_PROFILE:-wakey-notary}"
DIRECT_PLIST="$REPO_ROOT/Config/WakeyInfo-Direct.plist"

build=1
publish=1
notes_file=""
while (($#)); do
    case "$1" in
        --no-publish) publish=0 ;;
        --publish-only) build=0 ;;
        --notes-file) notes_file="${2:?--notes-file needs a path}"; shift ;;
        -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option $1" ;;
    esac
    shift
done
((build || publish)) || die "--no-publish and --publish-only together do nothing"

version=$(read_setting MARKETING_VERSION)
build_number=$(read_build_number)
tag="v$version"
out="$REPO_ROOT/release/$version"
app="$out/export/Wakey.app"
zip_name="wakey-$version.zip"
zip="$out/$zip_name"
download_url="https://github.com/$GITHUB_REPO/releases/download/$tag/$zip_name"

sparkle_tool() {
    local tool="$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/$1"
    [[ -x "$tool" ]] || die "$tool missing; it appears after the first archive into build/DerivedData"
    echo "$tool"
}

# Everything that would stop a publish, checked before spending minutes on a build.
check_can_publish() {
    command -v gh >/dev/null || die "gh is not installed"
    gh auth status >/dev/null 2>&1 || die "gh is not signed in; run: gh auth login"

    check_clean_main

    if gh release view "$tag" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
        die "GitHub release $tag already exists; bump the version with scripts/bump.sh"
    fi

    local live_build
    live_build=$(sed -nE '/<sparkle:version>/{s|.*<sparkle:version>(.+)</sparkle:version>.*|\1|p;q;}' "$REPO_ROOT/appcast.xml")
    [[ "$live_build" =~ ^[0-9]+$ ]] || die "couldn't read the build number (<sparkle:version>) from appcast.xml"
    ((build_number > live_build)) ||
        die "build $build_number is not above the live appcast's build $live_build, so Sparkle would not offer it; run scripts/bump.sh"
}

check_keys() {
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
        die "notarytool profile '$NOTARY_PROFILE' is missing or invalid; see the one-time setup in .claude/skills/release-wakey/SKILL.md"
}

check_sparkle_key() {
    local expected actual
    expected=$(plist_value "$DIRECT_PLIST" SUPublicEDKey)
    actual=$("$(sparkle_tool generate_keys)" -p 2>/dev/null) ||
        die "no Sparkle EdDSA key in the keychain; updates can't be signed"
    [[ "$actual" == "$expected" ]] ||
        die "keychain Sparkle key ($actual) doesn't match SUPublicEDKey ($expected); clients would reject the update"
}

build_release() {
    # Start clean, but keep drafted release notes and the App Store build's artifacts.
    mkdir -p "$out"
    find "$out" -mindepth 1 -maxdepth 1 ! -name notes.md ! -name appstore -exec rm -rf {} +

    step "Archiving Wakey Direct $version ($build_number)"
    archive_app "Wakey Direct" "Release-Direct" "$out/Wakey.xcarchive" "$out/archive.log"
    check_archive_version "$out/Wakey.xcarchive" "$version" "$build_number"
    check_sparkle_key

    step "Exporting with Developer ID"
    cat >"$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
    <key>destination</key><string>export</string>
</dict>
</plist>
EOF
    run_xcodebuild "$out/export.log" -exportArchive \
        -archivePath "$out/Wakey.xcarchive" \
        -exportOptionsPlist "$out/ExportOptions.plist" \
        -exportPath "$out/export" \
        -allowProvisioningUpdates
    codesign --verify --deep --strict "$app" || die "exported app fails codesign verification"
    # Captured first: grep -q would exit early and SIGPIPE the producer under pipefail.
    local signing
    signing=$(codesign -dvv "$app" 2>&1)
    grep -q "^Authority=Developer ID Application: .*($TEAM_ID)" <<<"$signing" ||
        die "exported app isn't signed with the team's Developer ID Application certificate"
    ok "signed with Developer ID"

    step "Notarizing (usually a few minutes)"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$out/notarize.zip"
    # A rejection is handled below with its log, so don't let notarytool's exit status end the script first.
    xcrun notarytool submit "$out/notarize.zip" --keychain-profile "$NOTARY_PROFILE" \
        --wait --output-format json >"$out/notary.json" || true
    local status submission
    status=$(plutil -extract status raw -o - "$out/notary.json")
    submission=$(plutil -extract id raw -o - "$out/notary.json")
    if [[ "$status" != "Accepted" ]]; then
        xcrun notarytool log "$submission" --keychain-profile "$NOTARY_PROFILE" "$out/notary-log.json" || true
        die "notarization $status (submission $submission), details: $out/notary-log.json"
    fi
    rm "$out/notarize.zip"
    xcrun stapler staple -q "$app"
    local assessment
    assessment=$(spctl -a -vv -t exec "$app" 2>&1)
    grep -q "source=Notarized Developer ID" <<<"$assessment" ||
        die "Gatekeeper doesn't accept the stapled app"
    ok "notarized ($submission) and stapled"

    step "Packaging and signing the update"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
    local signature length min_os pub_date
    signature=$("$(sparkle_tool sign_update)" -p "$zip")
    length=$(stat -f %z "$zip")
    [[ -n "$signature" ]] || die "sign_update returned no signature"
    "$(sparkle_tool sign_update)" --verify "$zip" "$signature" >/dev/null 2>&1 ||
        die "the zip's Sparkle signature doesn't verify"
    min_os=$(plist_value "$app/Contents/Info.plist" LSMinimumSystemVersion)
    pub_date=$(LC_ALL=C date "+%a, %d %b %Y %H:%M:%S %z")
    # Written aside and moved into place only once valid, so --publish-only never finds a bad appcast.
    cat >"$out/appcast.xml.tmp" <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Wakey</title>
        <item>
            <title>$version</title>
            <pubDate>$pub_date</pubDate>
            <sparkle:version>$build_number</sparkle:version>
            <sparkle:shortVersionString>$version</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>$min_os</sparkle:minimumSystemVersion>
            <enclosure url="$download_url" length="$length" type="application/octet-stream" sparkle:edSignature="$signature"/>
        </item>
    </channel>
</rss>
EOF
    xmllint --noout "$out/appcast.xml.tmp" ||
        die "generated appcast.xml is not valid XML"
    mv "$out/appcast.xml.tmp" "$out/appcast.xml"
    # Lets --publish-only check it's publishing a build of the commit being released.
    printf 'commit=%s\nbuild=%s\nclean=%s\n' \
        "$(git -C "$REPO_ROOT" rev-parse HEAD)" "$build_number" \
        "$([[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] && echo 1 || echo 0)" >"$out/build-info"
    ok "$zip_name ($length bytes), appcast.xml written"
}

write_default_notes() {
    local previous
    previous=$(gh release view --repo "$GITHUB_REPO" --json tagName --jq .tagName 2>/dev/null || true)
    git -C "$REPO_ROOT" fetch --quiet --tags origin || true
    {
        printf '🎉 new update\n\n'
        if [[ -n "$previous" ]] && git -C "$REPO_ROOT" rev-parse -q --verify "$previous" >/dev/null; then
            git -C "$REPO_ROOT" log "$previous..HEAD" --no-merges --format='- %s' |
                grep -vE '^- (chore|test|docs|ci|build)(\(.*\))?:' || true
        fi
    } >"$out/notes.md"
}

# The staged artifacts must be a build of exactly what's being tagged: built from this commit, at this build
# number, from a clean tree, and still notarized.
check_artifacts_match_head() {
    local file
    for file in "$zip" "$out/appcast.xml" "$out/build-info"; do
        [[ -f "$file" ]] || die "$file is missing; run without --publish-only first"
    done

    local built_commit built_build built_clean staged_build head
    built_commit=$(sed -n 's/^commit=//p' "$out/build-info")
    built_build=$(sed -n 's/^build=//p' "$out/build-info")
    built_clean=$(sed -n 's/^clean=//p' "$out/build-info")
    staged_build=$(sed -nE '/<sparkle:version>/{s|.*<sparkle:version>(.+)</sparkle:version>.*|\1|p;q;}' "$out/appcast.xml")
    head=$(git -C "$REPO_ROOT" rev-parse HEAD)

    [[ "$built_commit" == "$head" ]] ||
        die "release/$version was built from ${built_commit:0:7}, but main is at ${head:0:7}; rebuild without --publish-only"
    [[ "$built_clean" == 1 ]] ||
        die "release/$version was built with uncommitted or untracked files; rebuild without --publish-only"
    [[ "$built_build" == "$build_number" && "$staged_build" == "$build_number" ]] ||
        die "release/$version holds build $staged_build, but Version.xcconfig says $build_number; rebuild without --publish-only"
    xcrun stapler validate -q "$app" || die "$app is no longer stapled; rebuild without --publish-only"
}

publish_release() {
    check_artifacts_match_head
    if [[ -n "$notes_file" ]]; then
        cp "$notes_file" "$out/notes.md"
    elif [[ ! -f "$out/notes.md" ]]; then
        write_default_notes
    fi

    step "Ready to publish $tag"
    echo "Release notes ($out/notes.md):"
    sed 's/^/    /' "$out/notes.md"
    echo
    echo "This will:"
    echo "  1. create the public GitHub release $tag on $GITHUB_REPO with $zip_name"
    echo "  2. commit appcast.xml and push it to main, which offers the update to every Wakey user"
    if ! confirm "Publish?"; then
        echo "Not published. Edit $out/notes.md if needed, then run: scripts/release-direct.sh --publish-only"
        exit 0
    fi

    gh release create "$tag" "$zip" --repo "$GITHUB_REPO" \
        --target "$(git -C "$REPO_ROOT" rev-parse HEAD)" \
        --title "$tag" --notes-file "$out/notes.md"
    ok "GitHub release $tag created"

    # A just-uploaded asset can take a moment to be served, so retry before giving up.
    local served expected attempt
    expected=$(stat -f %z "$zip")
    for attempt in 1 2 3 4 5 6; do
        served=$(curl -sfL "$download_url" | wc -c | tr -d ' ') || served=0
        [[ "$served" == "$expected" ]] && break
        sleep 5
    done
    [[ "$served" == "$expected" ]] ||
        die "downloaded $served bytes from $download_url, expected $expected; appcast NOT pushed"

    cp "$out/appcast.xml" "$REPO_ROOT/appcast.xml"
    git -C "$REPO_ROOT" commit --quiet -m "chore: release $tag" -- appcast.xml
    git -C "$REPO_ROOT" push --quiet origin main
    ok "appcast.xml pushed to main; Sparkle clients will see $version within a few minutes (GitHub raw caches ~5 min)"
}

if ((publish)); then
    check_can_publish
fi
if ((build)); then
    check_keys
    build_release
fi
if ((publish)); then
    check_can_publish
    publish_release
else
    step "Built $version ($build_number) in $out"
    echo "To publish later: scripts/release-direct.sh --publish-only"
fi
