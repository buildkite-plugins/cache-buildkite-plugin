#!/bin/bash
set -euo pipefail

lock () {
  local file="${1}.lock"
  (
    set -o noclobber
    date > "${file}"
  ) 2>/dev/null
}

wait_and_lock () {
  local file="${1}.lock"
  local max_attempts="${2:-5}"

  for ATTEMPT in $(seq 1 "${max_attempts}"); do
    if ! lock "${1}"; then
      echo "Waiting for folder lock ${file}"
      sleep "${ATTEMPT}"
    else
      return 0
    fi
  done

  return 1
}

release_lock () {
  local file="${1}.lock"
  rm -f "${file}"
}
