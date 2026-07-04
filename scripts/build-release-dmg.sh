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
  NOTARY_WAIT_TIMEOUT                   Maximum time to wait for notarization.
                                        Default: 45m
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
NOTARY_WAIT_TIMEOUT="${NOTARY_WAIT_TIMEOUT:-45m}"
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

json_value() {
  local key="$1"
  local file="$2"
  plutil -extract "$key" raw -o - "$file" 2>/dev/null || true
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
  notary wait timeout: $NOTARY_WAIT_TIMEOUT
EOF
}

dry_run() {
  require_tool xcodebuild
  require_tool hdiutil
  require_tool codesign
  require_tool xcrun
  require_tool plutil
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
  local notary_log_json
  local notary_message
  local notary_status
  local submission_id
  local submit_json
  local wait_json
  TEMP_DIR="$(mktemp -d)"
  key_path="$TEMP_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
  submit_json="$OUTPUT_DIR/notary-submit-$VERSION-$BUILD_NUMBER.json"
  wait_json="$OUTPUT_DIR/notary-wait-$VERSION-$BUILD_NUMBER.json"
  notary_log_json="$OUTPUT_DIR/notary-log-$VERSION-$BUILD_NUMBER.json"
  printf '%s' "$APP_STORE_CONNECT_PRIVATE_KEY" > "$key_path"
  chmod 600 "$key_path"

  echo "Submitting $DMG_PATH to Apple notarization."
  xcrun notarytool submit \
    "$DMG_PATH" \
    --key "$key_path" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --output-format json \
    --no-progress \
    > "$submit_json"

  cat "$submit_json"
  submission_id="$(json_value id "$submit_json")"
  if [ -z "$submission_id" ]; then
    echo "notarytool submit did not return a submission id. Response saved to $submit_json" >&2
    exit 1
  fi

  echo "Notary submission ID: $submission_id"
  echo "Notary submit response saved to $submit_json"
  echo "Waiting up to $NOTARY_WAIT_TIMEOUT for notarization to complete."
  if ! xcrun notarytool wait \
    "$submission_id" \
    --key "$key_path" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --output-format json \
    --no-progress \
    --timeout "$NOTARY_WAIT_TIMEOUT" \
    > "$wait_json"; then
    echo "notarytool wait failed or timed out for submission $submission_id." >&2
    if [ -s "$wait_json" ]; then
      cat "$wait_json" >&2
    fi
    echo "Notary wait response saved to $wait_json" >&2
    echo "Check later with: xcrun notarytool info $submission_id --key <AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8> --key-id $APP_STORE_CONNECT_KEY_ID --issuer $APP_STORE_CONNECT_ISSUER_ID" >&2
    exit 1
  fi

  cat "$wait_json"
  echo "Notary wait response saved to $wait_json"
  notary_status="$(json_value status "$wait_json")"
  notary_message="$(json_value message "$wait_json")"
  echo "Notary status for $submission_id: ${notary_status:-unknown}"
  if [ -n "$notary_message" ]; then
    echo "Notary message: $notary_message"
  fi

  case "$notary_status" in
    Accepted)
      ;;
    Invalid|Rejected)
      echo "Notarization $notary_status for submission $submission_id. Fetching notary log." >&2
      if xcrun notarytool log \
        "$submission_id" \
        "$notary_log_json" \
        --key "$key_path" \
        --key-id "$APP_STORE_CONNECT_KEY_ID" \
        --issuer "$APP_STORE_CONNECT_ISSUER_ID"; then
        cat "$notary_log_json" >&2
        echo "Notary log saved to $notary_log_json" >&2
      else
        echo "Failed to fetch notary log for submission $submission_id." >&2
      fi
      exit 1
      ;;
    *)
      echo "Unexpected notary status '${notary_status:-missing}' for submission $submission_id." >&2
      echo "Notary wait response saved to $wait_json" >&2
      echo "Check later with: xcrun notarytool info $submission_id --key <AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8> --key-id $APP_STORE_CONNECT_KEY_ID --issuer $APP_STORE_CONNECT_ISSUER_ID" >&2
      exit 1
      ;;
  esac

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
require_tool plutil
require_tool shasum
prepare_export_options
print_plan
build_archive
export_archive
create_dmg
notarize_dmg
checksum_dmg
