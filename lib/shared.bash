#!/bin/bash

is_debug() {
  [[ "${BUILDKITE_PLUGIN_CACHE_DEBUG:-false}" =~ ^(true|on|1)$ ]]
}

# Hashes files and directories recursively
hash_files() {
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

  find "$@" -type f -print0 \
    | xargs -0 "$shasum" \
    | awk '{print $1}' \
    | sort \
    | "$shasum" \
    | awk '{print $1}'
}

build_manifest_cache_path()  {
  local manifest="$1"
  echo "${BUILDKITE_AGENT_CACHE_PATH?}/manifest/$(hash_files "$manifest")"
}