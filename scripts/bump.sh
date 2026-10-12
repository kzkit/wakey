#!/bin/bash
# Bumps Wakey's version in Config/Version.xcconfig and commits the change.
#
#   scripts/bump.sh 1.0.4        new marketing version, build number + 1
#   scripts/bump.sh              same marketing version, build number + 1
#   scripts/bump.sh --no-commit  edit the file only
#
# The build number always goes up: App Store Connect rejects reused build numbers
# and Sparkle only offers an update whose build number is higher than the installed one.
set -euo pipefail
source "$(dirname "$0")/release-common.sh"

commit=1
new_version=""
for arg in "$@"; do
    case "$arg" in
        --no-commit) commit=0 ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option $arg" ;;
        *) new_version="$arg" ;;
    esac
done

old_version=$(read_setting MARKETING_VERSION)
old_build=$(read_setting CURRENT_PROJECT_VERSION)
new_version=${new_version:-$old_version}

[[ "$new_version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || die "version must look like 1.2 or 1.2.3, got '$new_version'"
[[ "$old_build" =~ ^[1-9][0-9]*$ ]] || die "CURRENT_PROJECT_VERSION must be a positive integer, got '$old_build'"
new_build=$((old_build + 1))
if [[ "$new_version" != "$old_version" ]] &&
    [[ "$(printf '%s\n%s\n' "$old_version" "$new_version" | sort -V | tail -1)" != "$new_version" ]]; then
    die "$new_version is lower than the current $old_version"
fi

sed -i '' -E \
    -e "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $new_version/" \
    -e "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $new_build/" \
    "$VERSION_CONFIG"

ok "$old_version ($old_build) → $new_version ($new_build)"

if ((commit)); then
    git -C "$REPO_ROOT" commit --quiet -m "chore: bump version to $new_version ($new_build)" -- "$VERSION_CONFIG"
    ok "committed $(git -C "$REPO_ROOT" rev-parse --short HEAD) on $(git -C "$REPO_ROOT" branch --show-current)"
fi
