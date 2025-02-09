#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/plugin.bash
. "${DIR}/plugin.bash"

validate_compression() {
  local COMPRESSION="$1"

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
  local COMPRESSED_FILE="$1"
  local FILE="$2"

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  if [ "${COMPRESSION}" != 'none' ]; then
    echo "Compressing ${COMPRESSED_FILE} with ${COMPRESSION}..."
    PATH="${PATH}:${DIR}/../compression" "${COMPRESSION}_wrapper" "compress" "${COMPRESSED_FILE}" "${FILE}"
  fi
}

uncompress() {
  local FILE="$1"
  local RESTORE_PATH="$2"

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  if [ "${COMPRESSION}" != 'none' ]; then
    echo "Cache is compressed, uncompressing with ${COMPRESSION}..."
    PATH="${PATH}:${DIR}/../compression" "${COMPRESSION}_wrapper" "decompress" "${FILE}" "${RESTORE_PATH}"
  fi
}
