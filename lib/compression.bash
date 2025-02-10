#!/bin/bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/plugin.bash
. "${DIR}/plugin.bash"

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

decompress() {
  local FILE="$1"
  local RESTORE_PATH="$2"

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  if [ "${COMPRESSION}" != 'none' ]; then
    echo "Cache is compressed, decompressing with ${COMPRESSION}..."
    PATH="${PATH}:${DIR}/../compression" "${COMPRESSION}_wrapper" "decompress" "${FILE}" "${RESTORE_PATH}"
  fi
}
