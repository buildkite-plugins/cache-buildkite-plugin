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

  echo "Compressing ${COMPRESSED_FILE} with ${COMPRESSION}..."

  if [ "${COMPRESSION}" = 'tgz' ]; then
    TAR_OPTS='cz'
    if is_absolute_path "${COMPRESSED_FILE}"; then
      TAR_OPTS="${TAR_OPTS}"P
    fi

    tar "${TAR_OPTS}"f "${FILE}" "${COMPRESSED_FILE}"
  elif [ "${COMPRESSION}" = 'zip' ]; then
    if is_absolute_path "${COMPRESSED_FILE}"; then
      local COMPRESS_DIR
      COMPRESS_DIR="$(dirname "${COMPRESSED_FILE}")"
      ( # subshell to avoid changing the working directory
        # shellcheck disable=SC2164 # we will exit anyway
        cd "${COMPRESS_DIR}"
        # because ZIP complains if the file does not end with .zip
        zip -r "${FILE}.zip" "${COMPRESSED_FILE}"
        mv "${FILE}.zip" "${FILE}"
      )
    else
      # because ZIP complains if the file does not end with .zip
      zip -r "${FILE}.zip" "${COMPRESSED_FILE}"
      mv "${FILE}.zip" "${FILE}"
    fi
  fi
}

uncompress() {
  local FILE="$1"
  local RESTORE_PATH="$2"

  local COMPRESSION=''
  COMPRESSION="$(plugin_read_config COMPRESSION 'none')"

  echo "Cache is compressed, uncompressing with ${COMPRESSION}..."

  if [ "${COMPRESSION}" = 'tgz' ]; then
    TAR_OPTS='xz'
    if is_absolute_path "${RESTORE_PATH}"; then
      TAR_OPTS="${TAR_OPTS}"P
    fi

    tar "${TAR_OPTS}"f "${FILE}" "${RESTORE_PATH}"
  elif [ "${COMPRESSION}" = 'zip' ]; then
    if is_absolute_path "${RESTORE_PATH}"; then
      local RESTORE_DIR
      RESTORE_DIR="$(dirname "${RESTORE_PATH}")"
      ( # subshell to avoid changing the working directory
        mkdir -p "${RESTORE_DIR}"
        # shellcheck disable=SC2164 # we will exit anyway
        cd "${RESTORE_DIR}"
        mv "${FILE}" "${RESTORE_DIR}/compressed.zip"
        unzip -o "compressed.zip"
        rm "compressed.zip"
      )
    else
      # because ZIP complains if the file does not end with .zip
      mv "${FILE}" "${FILE}.zip"
      unzip -o "${FILE}.zip"
    fi
  fi
}

is_absolute_path() {
  local FILEPATH="${1}"
  [ "${FILEPATH:0:1}" = "/" ]
}
