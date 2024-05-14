#!/bin/bash

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# shellcheck source=lib/plugin.bash
. "${DIR}/plugin.bash"

validate_compression() {
  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  VALID_COMPRESSIONS=(none tgz zip)
  for VALID in "${VALID_COMPRESSIONS[@]}"; do
    if [ "${COMPRESSION}" = "${VALID}" ]; then
      return 0
    fi
  done

  return 1
}

compression_active() {
  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  [ "${COMPRESSION}" != 'none' ]
}

compress() {
  local PATH="$1"
  local FILE="$2"

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  if [ "${COMPRESSION}" = 'tgz' ]; then
    COMPRESS_COMMAND=(tar czf "${FILE}" "${PATH}")
  elif [ "${COMPRESSION}" = 'zip' ]; then
    COMPRESS_COMMAND=(zip -r "${FILE}" "${PATH}")
  else
    echo 'uncompress should not be called when compression is not setup'
    exit 1
  fi

  echo "Compressing ${PATH} with ${COMPRESSION}..."
  "${COMPRESS_COMMAND[@]}"
}

uncompress() {
  local FILE="$1"
  local _RESTORE_PATH="$2" # pretty sure this is not necessary

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  if [ "${COMPRESSION}" = 'tgz' ]; then
    UNCOMPRESS_COMMAND=(tar xzf "${FILE}")
  elif [ "${COMPRESSION}" = 'zip' ]; then
    UNCOMPRESS_COMMAND=(unzip "${FILE}")
  else
    echo 'uncompress should not be called when compression is not setup'
    exit 1
  fi

  "${UNCOMPRESS_COMMAND[@]}"
}
