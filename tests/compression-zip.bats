#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export HASH_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=zip

  source "${PWD}/lib/compression.bash"
}

@test 'compress with absolute path' {
  touch compressed
  mkdir -p /tmp/tests/data/my_files

  stub zip \
    "-r \* \* : touch \$2; echo compressed \${@:3} into \$2"

  run compress /tmp/tests/data/my_files compressed

  assert_success
  assert_output --partial 'Compressing /tmp/tests/data/my_files with zip...'

  unstub zip
  rm -rf /tmp/tests/data/my_files
}

@test 'uncompress with absolute path' {
  touch compressed
  stub unzip \
    "-o \* \* : echo uncompressed \$3 into \$4"

  run uncompress compressed /tmp/tests/data/my_files

  assert_success
  assert_output --partial 'Cache is compressed, uncompressing with zip...'

  unstub unzip
}
@test 'compress with relative path' {
  touch compressed
  mkdir -p data/my_files

  stub zip \
    "-r \* \* : touch \$2; echo compressed \${@:3} into \$2"

  run compress data/my_files compressed

  assert_success
  assert_output --partial 'Compressing data/my_files with zip...'

  unstub zip
  rm -rf data/my_files
}

@test 'uncompress with relative path' {
  touch compressed
  stub unzip \
    "-o \* \* : echo uncompressed \$3 into \$4"

  run uncompress compressed data/my_files

  assert_success
  assert_output --partial 'Cache is compressed, uncompressing with zip...'

  unstub unzip
  rm compressed.zip
}
