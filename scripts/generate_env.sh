#!/usr/bin/env bash
#
# Generates the env/env.json files the samples read their Stream credentials
# from.
#
# Every sample ships an env/env.example.json listing the values it needs. This
# script copies it to env/env.json, fills in your API key, and signs a user token
# for every STREAM_TOKEN_<USER_ID> entry with your API secret. The secret is
# only used locally to sign the tokens and is never written to disk.
#
# Usage:
#   scripts/generate_env.sh [--force] [sample-dir ...]
#
# With no sample-dir, every sample in the repository is configured. Existing
# env/env.json files are kept unless --force is passed.
#
# The API key and secret are read from STREAM_API_KEY and STREAM_API_SECRET,
# or prompted for when those are not set. Both are on the Stream Dashboard:
# https://dashboard.getstream.io/
#
# The tokens never expire, which is fine for trying the samples out. In a
# production app, generate tokens on your server instead:
# https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/

# Re-run with bash when started as `sh scripts/generate_env.sh`.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

force=false
samples=()
for arg in "$@"; do
  case "$arg" in
    --force) force=true ;;
    -h | --help)
      sed -n '3,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) samples+=("$arg") ;;
  esac
done

if ! command -v openssl > /dev/null; then
  echo "error: openssl is required to sign the user tokens." >&2
  exit 1
fi

if [[ ${#samples[@]} -eq 0 ]]; then
  examples="$(find "$repo_root/packages" -path '*/env/env.example.json' -not -path '*/build/*' | sort)"
  while IFS= read -r example; do
    if [[ -n "$example" ]]; then
      samples+=("$(dirname "$(dirname "$example")")")
    fi
  done <<< "$examples"
fi
if [[ ${#samples[@]} -eq 0 ]]; then
  echo "error: no samples with an env/env.example.json found." >&2
  exit 1
fi

api_key="${STREAM_API_KEY:-}"
api_secret="${STREAM_API_SECRET:-}"
if [[ -z "$api_key" ]]; then
  read -r -p "Stream API key: " api_key
fi
if [[ -z "$api_secret" ]]; then
  read -r -s -p "Stream API secret (not stored): " api_secret
  echo
fi
if [[ -z "$api_key" || -z "$api_secret" ]]; then
  echo "error: both the API key and the API secret are required." >&2
  exit 1
fi

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# Signs an HS256 JWT for the given user id, the same token Stream's server
# SDKs and the online token generator produce.
user_token() {
  local header payload signature
  header="$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | base64url)"
  payload="$(printf '{"user_id":"%s"}' "$1" | base64url)"
  signature="$(printf '%s' "$header.$payload" \
    | openssl dgst -sha256 -hmac "$api_secret" -binary | base64url)"
  printf '%s.%s.%s' "$header" "$payload" "$signature"
}

for sample in "${samples[@]}"; do
  sample="${sample%/}"
  example="$sample/env/env.example.json"
  target="$sample/env/env.json"

  if [[ ! -f "$example" ]]; then
    echo "skip  $sample (no env/env.example.json)" >&2
    continue
  fi
  if [[ -f "$target" && "$force" != true ]]; then
    echo "keep  $target (already exists, pass --force to overwrite)"
    continue
  fi

  # env/env.example.json has one "NAME": "value" entry per line. The API key and
  # the tokens are filled in, every other entry is copied as is.
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([[:space:]]*)\"STREAM_API_KEY\":[[:space:]]*\"[^\"]*\"(,?)$ ]]; then
      printf '%s"STREAM_API_KEY": "%s"%s\n' \
        "${BASH_REMATCH[1]}" "$api_key" "${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^([[:space:]]*)\"STREAM_TOKEN_([A-Z0-9_]+)\":[[:space:]]*\"[^\"]*\"(,?)$ ]]; then
      user_id="$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')"
      printf '%s"STREAM_TOKEN_%s": "%s"%s\n' \
        "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$(user_token "$user_id")" \
        "${BASH_REMATCH[3]}"
    else
      printf '%s\n' "$line"
    fi
  done < "$example" > "$target"

  echo "wrote $target"
done

echo
echo "Run a sample with flutter run."
