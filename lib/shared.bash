#!/bin/bash

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# shellcheck source=lib/plugin.bash
. "${DIR}/plugin.bash"

sha() {
  local shasum="false"

  # different operating systems have various shasum commands
  if hash shasum1 2>/dev/null ; then
    shasum="shasum1"
  elif hash shasum 2>/dev/null ; then
    shasum="shasum"
  elif hash sha1sum 2>/dev/null ; then
    shasum="sha1sum"
  else
    echo >&2 "No shasum implementation installed"
    return 1
  fi

  echo "$shasum"
}

# Hashes multiple files and directories recursively
hash_files() {
  ( for FILE in "$@"; do
      find "$FILE" -type f -print0
    done
  ) | sort -z \
    | xargs -0 "$(sha)" \
    | cut -d\  -f1 \
    | sort \
    | "$(sha)" \
    | cut -d\  -f1
}

build_key() {
  local LEVEL="$1"
  local CACHE_PATH="$2"
  local COMPRESSION="${3:-}"

  if [ "${LEVEL}" = 'file' ]; then
    plugin_read_list_into_result MANIFEST
    BASE="$(hash_files "${result[@]}")"
  elif [ "${LEVEL}" = 'step' ]; then
    BASE="${BUILDKITE_PIPELINE_SLUG}${BUILDKITE_LABEL}"
  elif [ "${LEVEL}" = 'branch' ]; then
    BASE="${BUILDKITE_PIPELINE_SLUG}${BUILDKITE_BRANCH}"
  elif [ "${LEVEL}" = 'pipeline' ]; then
    BASE="${BUILDKITE_PIPELINE_SLUG}"
  elif [ "${LEVEL}" = 'all' ]; then
    BASE="${BUILDKITE_ORGANIZATION_SLUG}"
  else
    echo "+++ 🚨 Invalid cache level ${LEVEL}" >&2
    exit 1
  fi

  echo "cache-${LEVEL}-${BASE}-${CACHE_PATH}-${COMPRESSION}" | "$(sha)" | cut -d\  -f1
}

backend_exec() {
  local BACKEND_NAME
  BACKEND_NAME=$(plugin_read_config BACKEND 'fs')

  PATH="${PATH}:${DIR}/../backends" "cache_${BACKEND_NAME}" "$@"
}
