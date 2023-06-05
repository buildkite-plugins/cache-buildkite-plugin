#!/bin/bash
set -euo pipefail

lock () {
  local folder="${1}.lock"
  (
    set -o noclobber
    date > "${folder}"
  ) 2>/dev/null
}

wait_and_lock () {
  local folder="${1}.lock"
  local max_attempts="${2:-5}"

  for ATTEMPT in $(seq 1 "${max_attempts}"); do
    if ! lock "${folder}"; then
      echo 'Waiting for folder lock'
      sleep "${ATTEMPT}"
    else
      return 0
    fi
  done

  return 1
}

release_lock () {
  local folder="${1}.lock"
  rm -f "${folder}"
}
