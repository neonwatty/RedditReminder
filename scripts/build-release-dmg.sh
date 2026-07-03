#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-release-dmg.sh [--dry-run]

Builds, exports, signs, notarizes, staples, validates, and checksums a
Developer ID DMG for RedditReminder.

Required for real builds:
  VERSION                               Semantic version without leading v.
  BUILD_NUMBER                          Integer build number.
  APPLE_TEAM_ID                         Apple Developer Team ID.
  APP_STORE_CONNECT_KEY_ID              App Store Connect API key ID.
  APP_STORE_CONNECT_ISSUER_ID           App Store Connect issuer ID.
  APP_STORE_CONNECT_PRIVATE_KEY         App Store Connect private key contents.

Optional:
  DEVELOPER_ID_APPLICATION              Code signing identity.
                                        Default: Developer ID Application
  RELEASE_OUTPUT_DIR                    Output directory.
                                        Default: build/release
  DERIVED_DATA_PATH                     DerivedData path.
                                        Default: build/release/DerivedData
EOF
}

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi
if [ "$#" -ne 0 ]; then
  usage >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RedditReminder"
SCHEME="RedditReminder"
CONFIGURATION="Release"
VERSION="${VERSION:-0.0.0-dry-run}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
OUTPUT_DIR="${RELEASE_OUTPUT_DIR:-$REPO_ROOT/build/release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$OUTPUT_DIR/DerivedData}"
ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
DMG_ROOT="$OUTPUT_DIR/dmg-root"
DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION-macos.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
EXPORT_OPTIONS_TEMPLATE="$REPO_ROOT/ExportOptions.plist"
EXPORT_OPTIONS="$OUTPUT_DIR/ExportOptions.plist"
DEVELOPER_ID_APPLICATION="${DEVELOPER_ID_APPLICATION:-Developer ID Application}"
TEMP_DIR=""

cleanup() {
  if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1" >&2
    exit 2
  fi
}

require_env() {
  if [ -z "${!1:-}" ]; then
    echo "Missing required environment variable: $1" >&2
    exit 2
  fi
}

validate_inputs() {
  if [ "$DRY_RUN" -eq 0 ]; then
    if ! printf '%s' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'; then
      echo "VERSION must be a semantic version without a leading v." >&2
      exit 2
    fi
    if ! printf '%s' "$BUILD_NUMBER" | grep -Eq '^[0-9]+$'; then
      echo "BUILD_NUMBER must be an integer." >&2
      exit 2
    fi
    require_env APPLE_TEAM_ID
    require_env APP_STORE_CONNECT_KEY_ID
    require_env APP_STORE_CONNECT_ISSUER_ID
    require_env APP_STORE_CONNECT_PRIVATE_KEY
  fi
}

prepare_export_options() {
  mkdir -p "$OUTPUT_DIR"
  cp "$EXPORT_OPTIONS_TEMPLATE" "$EXPORT_OPTIONS"
  if [ "$DRY_RUN" -eq 0 ]; then
    sed -i '' "s/\$(APPLE_TEAM_ID)/$APPLE_TEAM_ID/g" "$EXPORT_OPTIONS"
  fi
}

print_plan() {
  cat <<EOF
Release DMG plan:
  app: $APP_NAME
  scheme: $SCHEME
  configuration: $CONFIGURATION
  version: $VERSION
  build: $BUILD_NUMBER
  archive: $ARCHIVE_PATH
  export: $EXPORT_PATH
  dmg: $DMG_PATH
  checksum: $CHECKSUM_PATH
  export options: $EXPORT_OPTIONS
EOF
}

dry_run() {
  require_tool xcodebuild
  require_tool hdiutil
  require_tool codesign
  require_tool xcrun
  require_tool shasum
  [ -f "$EXPORT_OPTIONS_TEMPLATE" ] || {
    echo "Missing $EXPORT_OPTIONS_TEMPLATE" >&2
    exit 2
  }
  prepare_export_options
  print_plan
  echo "Dry run only; no archive, signing, notarization, or DMG was created."
}

build_archive() {
  rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DMG_ROOT" "$DMG_PATH" "$CHECKSUM_PATH"
  xcodebuild archive \
    -project "$REPO_ROOT/RedditReminder.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_ENTITLEMENTS= \
    ENABLE_HARDENED_RUNTIME=YES \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
}

export_archive() {
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

  codesign --verify --deep --strict "$EXPORT_PATH/$APP_NAME.app"
  codesign -dvvv "$EXPORT_PATH/$APP_NAME.app"
  codesign -d --entitlements :- "$EXPORT_PATH/$APP_NAME.app" || true

  local app_version
  local app_build
  app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXPORT_PATH/$APP_NAME.app/Contents/Info.plist")"
  app_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXPORT_PATH/$APP_NAME.app/Contents/Info.plist")"
  if [ "$app_version" != "$VERSION" ]; then
    echo "Expected app version $VERSION, found $app_version" >&2
    exit 1
  fi
  if [ "$app_build" != "$BUILD_NUMBER" ]; then
    echo "Expected app build $BUILD_NUMBER, found $app_build" >&2
    exit 1
  fi
}

create_dmg() {
  mkdir -p "$DMG_ROOT"
  cp -R "$EXPORT_PATH/$APP_NAME.app" "$DMG_ROOT/$APP_NAME.app"
  ln -s /Applications "$DMG_ROOT/Applications"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

  codesign --force --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DMG_PATH"
}

notarize_dmg() {
  local key_path
  TEMP_DIR="$(mktemp -d)"
  key_path="$TEMP_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  printf '%s' "$APP_STORE_CONNECT_PRIVATE_KEY" > "$key_path"
  chmod 600 "$key_path"

  xcrun notarytool submit \
    "$DMG_PATH" \
    --key "$key_path" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait

  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"
}

checksum_dmg() {
  (
    cd "$(dirname "$DMG_PATH")"
    shasum -a 256 "$(basename "$DMG_PATH")"
  ) > "$CHECKSUM_PATH"
  echo "Created $DMG_PATH"
  echo "Created $CHECKSUM_PATH"
}

validate_inputs

if [ "$DRY_RUN" -eq 1 ]; then
  dry_run
  exit 0
fi

require_tool xcodebuild
require_tool hdiutil
require_tool codesign
require_tool xcrun
require_tool shasum
prepare_export_options
print_plan
build_archive
export_archive
create_dmg
notarize_dmg
checksum_dmg
