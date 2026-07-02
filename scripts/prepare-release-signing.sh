#!/usr/bin/env bash
set -euo pipefail

required_env=(
  APPLE_TEAM_ID
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_PRIVATE_KEY
)

certificate_path=""

cleanup() {
  if [ -n "$certificate_path" ]; then
    rm -f "$certificate_path"
  fi
}
trap cleanup EXIT

missing=()
for name in "${required_env[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Missing release environment variable(s): %s\n' "${missing[*]}" >&2
  exit 2
fi

certificate_values=(
  "${DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64:-}"
  "${DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD:-}"
  "${KEYCHAIN_PASSWORD:-}"
)

certificate_value_count=0
for value in "${certificate_values[@]}"; do
  if [ -n "$value" ]; then
    certificate_value_count=$((certificate_value_count + 1))
  fi
done

if [ "$certificate_value_count" -gt 0 ] && [ "$certificate_value_count" -lt "${#certificate_values[@]}" ]; then
  echo "Developer ID certificate import is partially configured; set certificate, certificate password, and keychain password." >&2
  exit 2
fi

if [ "$certificate_value_count" -eq "${#certificate_values[@]}" ]; then
  keychain_path="${RUNNER_TEMP:-/tmp}/redditreminder-release.keychain-db"
  certificate_path="${RUNNER_TEMP:-/tmp}/redditreminder-developer-id.p12"

  printf '%s' "$DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64" | base64 --decode > "$certificate_path"
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$keychain_path"
  security set-keychain-settings -lut 21600 "$keychain_path"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$keychain_path"
  security import "$certificate_path" -P "$DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain_path"
  rm -f "$certificate_path"
  certificate_path=""

  existing_keychains=()
  while IFS= read -r keychain; do
    if [ -n "$keychain" ]; then
      existing_keychains+=("$keychain")
    fi
  done < <(security list-keychains -d user | sed 's/[ "]//g')

  security list-keychains -d user -s "$keychain_path" "${existing_keychains[@]}"
  security default-keychain -d user -s "$keychain_path"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$keychain_path"
fi

identity="${DEVELOPER_ID_APPLICATION:-Developer ID Application}"
if ! security find-identity -p codesigning -v | grep -F "$identity" >/dev/null; then
  echo "No usable code signing identity found matching: $identity" >&2
  security find-identity -p codesigning -v >&2 || true
  exit 2
fi

echo "Release signing prerequisites verified."
