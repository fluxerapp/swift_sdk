#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUTPUT="${FLUXER_OPENAPI_OUTPUT:-Sources/Fluxer/openapi.json}"
UPSTREAM_URL="${FLUXER_OPENAPI_URL:-https://raw.githubusercontent.com/fluxerapp/fluxer/main/fluxer_api/src/api/openapi/openapi.json}"

command -v python3 >/dev/null 2>&1 || {
  echo "python3 not found" >&2
  exit 1
}

RAW="$(mktemp "${TMPDIR:-/tmp}/fluxer-openapi.raw.XXXXXX")"
trap 'rm -f "$RAW"' EXIT

if [[ -n "${FLUXER_OPENAPI_SOURCE:-}" ]]; then
  if [[ ! -f "$FLUXER_OPENAPI_SOURCE" ]]; then
    echo "FLUXER_OPENAPI_SOURCE not found: $FLUXER_OPENAPI_SOURCE" >&2
    exit 1
  fi
  cp "$FLUXER_OPENAPI_SOURCE" "$RAW"
  echo "Using FLUXER_OPENAPI_SOURCE ($FLUXER_OPENAPI_SOURCE)"
elif [[ -f "../fluxer/fluxer_api/src/api/openapi/openapi.json" ]]; then
  cp "../fluxer/fluxer_api/src/api/openapi/openapi.json" "$RAW"
  echo "Using ../fluxer/fluxer_api/src/api/openapi/openapi.json"
elif [[ -f "../fluxer_api/src/api/openapi/openapi.json" ]]; then
  cp "../fluxer_api/src/api/openapi/openapi.json" "$RAW"
  echo "Using ../fluxer_api/src/api/openapi/openapi.json"
else
  command -v curl >/dev/null 2>&1 || {
    echo "curl not found and no local fluxer checkout" >&2
    exit 1
  }
  echo "Downloading $UPSTREAM_URL"
  curl -fsSL -o "$RAW" "$UPSTREAM_URL"
fi

echo "Fetched $(wc -c < "$RAW") bytes"
mkdir -p "$(dirname "$OUTPUT")"
python3 scripts/patch_openapi_for_swift.py "$RAW" "$OUTPUT"
echo "Wrote $OUTPUT"
