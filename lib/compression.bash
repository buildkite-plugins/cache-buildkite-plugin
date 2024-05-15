#!/bin/bash

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

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

  echo "Compressing ${COMPRESSED_FILE} with ${COMPRESSION}..."

  if [ "${COMPRESSION}" = 'tgz' ]; then
    tar czf "${FILE}" "${COMPRESSED_FILE}"
  elif [ "${COMPRESSION}" = 'zip' ]; then
    # because ZIP complains if the file does not end with .zip
    zip -r "${FILE}.zip" "${COMPRESSED_FILE}"
    mv "${FILE}.zip" "${FILE}"
  fi
}

uncompress() {
  local FILE="$1"
  local _RESTORE_PATH="$2" # pretty sure this is not necessary

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  echo "Cache is compressed, uncompressing with ${COMPRESSION}..."

  if [ "${COMPRESSION}" = 'tgz' ]; then
    tar xzf "${FILE}"
  elif [ "${COMPRESSION}" = 'zip' ]; then
    # because ZIP complains if the file does not end with .zip
    mv "${FILE}" "${FILE}.zip"
    unzip -o "${FILE}.zip"
  fi
}
