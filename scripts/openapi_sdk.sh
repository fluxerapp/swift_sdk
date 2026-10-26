#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail

USAGE="Usage: $0 validate | $0 regenerate"
GROUP_OPEN=0

escape_workflow_command() {
  local value="$1"
  value="${value//%/%25}"
  value="${value//$'\r'/%0D}"
  value="${value//$'\n'/%0A}"
  printf '%s' "$value"
}

error() {
  echo "::error::$(escape_workflow_command "$*")" >&2
}

notice() {
  echo "::notice::$(escape_workflow_command "$*")"
}

start_group() {
  echo "::group::$(escape_workflow_command "$1")"
  GROUP_OPEN=1
}

end_group() {
  if [[ "$GROUP_OPEN" == "1" ]]; then
    echo "::endgroup::"
    GROUP_OPEN=0
  fi
}

fail() {
  error "$1"
  exit "${2:-1}"
}

trap end_group EXIT

MODE="${1:-}"
if [[ "$MODE" != "validate" && "$MODE" != "regenerate" ]]; then
  fail "first argument must be validate or regenerate. $USAGE" 2
fi
shift

if [[ $# -ne 0 ]]; then
  fail "$MODE does not accept extra arguments. $USAGE" 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

command -v swift >/dev/null 2>&1 || fail "swift not found"
if [[ "$MODE" == "regenerate" ]]; then
  command -v git >/dev/null 2>&1 || fail "git not found"
  if [[ -z "${FLUXER_CI_APP_USER_ID:-}" ]]; then
    fail "FLUXER_CI_APP_USER_ID is required for regenerate"
  fi
fi

if [[ "$MODE" == "validate" ]]; then
  export FLUXER_OPENAPI_SOURCE="../fluxer_api/src/api/openapi/openapi.json"
else
  export FLUXER_OPENAPI_SOURCE="../fluxer/fluxer_api/src/api/openapi/openapi.json"
fi

start_group "Fetching upstream spec"
./scripts/fetch_openapi.sh
end_group

start_group "Building Swift package"
swift build
end_group

start_group "Running tests"
swift test
end_group

if [[ "$MODE" == "regenerate" ]]; then
  start_group "Committing SDK changes"
  git config user.name "fluxer-ci[bot]"
  git config user.email "${FLUXER_CI_APP_USER_ID}+fluxer-ci[bot]@users.noreply.github.com"

  git add -A
  if git diff --staged --quiet; then
    notice "No changes to commit."
    exit 0
  fi

  git commit -m "chore(sdk): regenerate from OpenAPI"
  git push origin HEAD:main
  end_group

  notice "Regeneration complete: changes were pushed."
else
  notice "Validation passed: upstream spec builds with Swift OpenAPI Generator patches."
fi
