---
name: release-wakey
description: Release a new version of Wakey — bump the version, build/notarize/publish the direct-download (Sparkle) build to GitHub Releases and the appcast, and upload the App Store build to App Store Connect. Use when the user asks to release, ship, publish, cut or upload a build, bump the version or build number, or update appcast.xml.
---

# Releasing Wakey

Wakey ships two builds from one codebase, both at the same version:

| | Direct (Sparkle) | App Store |
|---|---|---|
| Scheme / config | `Wakey Direct` / `Release-Direct` | `Wakey App Store` / `Release-AppStore` |
| Info.plist | `Config/WakeyInfo-Direct.plist` (has `SUFeedURL`, `SUPublicEDKey`) | `Config/WakeyInfo-AppStore.plist` |
| Signed with | Developer ID Application, notarized + stapled | Apple Distribution (App Store Connect re-signs) |
| Ships via | GitHub release `v<version>` with `wakey-<version>.zip`, plus `appcast.xml` on `main` | App Store Connect upload, then manual review submission |
| Script | `scripts/release-direct.sh` | `scripts/release-appstore.sh` |

The version lives only in `Config/Version.xcconfig` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`). It's the base configuration of every project-level build configuration, and no target overrides it.

## Release flow

1. **Preconditions.** Releases run from the **main checkout on `main`**, clean and in sync with `origin/main`. Everything going out must already be merged, with tests passing (`xcodebuild test -project Wakey.xcodeproj -scheme Wakey -destination 'platform=macOS'`) and verified in the running app.
2. **Pick the version with the user.** Usually patch for fixes and minor for features. Show what has changed since the last release: `gh release view --repo kzkit/wakey --json tagName --jq .tagName` gives the last tag, then `git log <tag>..origin/main --oneline --no-merges`.
3. **Bump:** `scripts/bump.sh <version>`. With no argument it bumps only the build number. It edits `Config/Version.xcconfig` and commits just that file on the current branch. Ask the user before pushing the bump commit to `main`. Past bumps went straight to `main`, but confirm each time.
4. **Draft release notes** into `release/<version>/notes.md`, matching the user's style:
   ```
   🎉 new update

   - Added …
   - Fixed …
   ```
   Write them for users, not as commit subjects. Show the draft to the user. If no notes file exists, the script writes a rough one from the commit subjects.
5. **Direct release: the user runs it in their own terminal.** Claude's shell hasn't been able to read the `wakey-notary` keychain item (notarytool reports "No Keychain password item found" there, but it works in the user's), and publishing asks for an interactive `y`. Give the user:
   ```bash
   scripts/release-direct.sh
   ```
   It archives, exports with Developer ID, notarizes (a few minutes), staples, zips with `ditto`, signs the zip with Sparkle's `sign_update`, and writes `release/<version>/appcast.xml`. Then it shows the notes and asks before it (a) creates the public GitHub release and (b) commits `appcast.xml` and pushes it to `main`. Step (b) is what offers the update to every user. `--no-publish` stops before publishing, and `--publish-only` publishes a previous run's artifacts (for example after editing the notes).
6. **App Store: also run by the user,** since upload needs a `y`:
   ```bash
   scripts/release-appstore.sh
   ```
   It archives and uploads to App Store Connect, with `manageAppVersionAndBuildNumber` off so the build keeps our build number. `--no-upload` exports a signed package locally instead. After processing, the user still adds the build to the version in App Store Connect and submits it for review.
7. **Verify after publishing.** Claude can do this:
   - `curl -s https://raw.githubusercontent.com/kzkit/wakey/main/appcast.xml` shows the new version and build. GitHub's raw CDN can lag about 5 minutes.
   - `gh release view v<version> --repo kzkit/wakey` shows the zip attached.
   - Optionally, run an older installed copy and use "Check for Updates…".

## What Claude can run itself

- `scripts/bump.sh`, plus reading and editing `Config/Version.xcconfig`.
- Usually `scripts/release-appstore.sh --no-upload`, to check that the App Store build archives and signs. Exports need Xcode's account credentials. They have worked from Claude's shell, but they have also failed there with `exportArchive No Accounts` while working for the user. In that case, hand the command to the user instead of retrying.
- Not `release-direct.sh`: notarization needs the `wakey-notary` keychain item. Never answer the publish or upload prompts on the user's behalf.
- Don't search or read keychain items to debug credential errors. Ask the user to run the command in their terminal instead.

## One-time setup (per Mac)

- **Xcode** signed in (Settings → Accounts) to the Apple account on team `C5JDGZ56JV`. The scripts use automatic, cloud-managed signing via `-allowProvisioningUpdates`, so the Developer ID and Distribution certificates don't need to be in the keychain.
- **Notarization profile:** the user runs this with their Apple ID and an app-specific password from account.apple.com → Sign-In and Security → App-Specific Passwords:
  ```bash
  xcrun notarytool store-credentials wakey-notary --apple-id <apple-id-email> --team-id C5JDGZ56JV
  ```
  `WAKEY_NOTARY_PROFILE` overrides the profile name.
- **Sparkle EdDSA private key** in the login keychain. It must match `SUPublicEDKey` (`/qRm+hCmfmynajXIxFnLitNnEnFZWhxjBZpfyNnbZsM=`), and the script checks this. On a new Mac, import a backup with `generate_keys -f <file>` (the tool is in `build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/` after the first archive). **Never generate a new key**: existing installs would reject every future update.
- **`gh auth login`** for `kzkit/wakey`.
- Optional App Store Connect API key for uploads: set `WAKEY_ASC_KEY_PATH`, `WAKEY_ASC_KEY_ID`, `WAKEY_ASC_ISSUER_ID`.

## Rules and gotchas

- **Build numbers only go up.** Sparkle compares `sparkle:version` (`CFBundleVersion`), and App Store Connect rejects reused builds. The direct script refuses to run if the build isn't above the live appcast's.
- **Don't edit Version/Build in Xcode's General tab.** It writes a target-level override into `project.pbxproj` that shadows the xcconfig. `grep -c 'MARKETING_VERSION\|CURRENT_PROJECT_VERSION' Wakey.xcodeproj/project.pbxproj` should print `0`. If it doesn't, delete those lines.
- **The appcast must never point at an asset that isn't live.** The script downloads the release zip and checks its size before pushing `appcast.xml`.
- **If publishing fails halfway**, the GitHub release exists, so `--publish-only` refuses. Finish by hand from the main checkout:
  - *The served-size check failed* ("appcast NOT pushed"): once `curl -sL <download url> | wc -c` matches the zip's size, run `cp release/<version>/appcast.xml appcast.xml && git commit -m "chore: release v<version>" -- appcast.xml && git push origin main`.
  - *The push failed* (the local `chore: release` commit exists): `git pull --rebase origin main && git push origin main`.
- **`--publish-only` only publishes a build of the current commit.** `release/<version>/build-info` records the commit, build number and a clean-tree flag. Publishing refuses if main has moved, the build number changed, or the build came from a dirty tree; rebuild in those cases.
- **Notarization rejected:** read `release/<version>/notary-log.json`. The usual causes are a missing hardened runtime or an unsigned nested binary in Sparkle.framework.
- `release/` and `build/` are gitignored. Never commit their contents. The root `appcast.xml` is the only release artifact in git.
- `appcast.xml` holds only the latest item, so the script regenerates the whole file each release.
