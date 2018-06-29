#!/bin/bash

is_debug() {
  [[ "${BUILDKITE_PLUGIN_CACHE_DEBUG:-false}" =~ ^(true|on|1)$ ]]
}

# Reads either a value or a list from environment
function prefix_read_list() {
  local prefix="$1"
  local parameter="${prefix}_0"

  if [[ -n "${!parameter:-}" ]]; then
    local i=0
    local parameter="${prefix}_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      echo "${!parameter}"
      i=$((i+1))
      parameter="${prefix}_${i}"
    done
  elif [[ -n "${!prefix:-}" ]]; then
    echo "${!prefix}"
  fi
}

# Returns a list of env vars in the form of BUILDKITE_PLUGIN_CACHE_PATHS_N
list_cache_entries() {
  while IFS='=' read -r name _ ; do
    if [[ $name =~ ^(BUILDKITE_PLUGIN_CACHE_PATHS_[0-9]+) ]] ; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < <(env | sort) | uniq
}

# Hashes files and directories recursively
hash_files() {
  local shasum="false"

  # different operating systems have various shasum commands
  if hash shasum1 2>/dev/null ; then
    shasum="shasum1"
  elif hash shasum 2>/dev/null ; then
    shasum="shasum"
  else
    echo >&2 "No shasum or shasum1 installed"
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

restore_cache() {
  local from="$1"
  local to="$2"
  cp -av "$from" "$to"
  ls -al "$to"
}

save_cache() {
  local from="$1"
  local to="$2"
  mkdir -p "$to"
  cp -av "$from" "$to"
  ls -al "$to"
}
