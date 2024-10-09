#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export HASH_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=tgz

  source "${PWD}/lib/compression.bash"
}

@test 'compress with absolute path' {
  stub tar \
    "czPf compressed \* : echo uncompressed \$2 into \$3"

  run compress /tmp/tests/data/my_files compressed

  assert_success
  assert_output --partial 'Compressing /tmp/tests/data/my_files with tgz...'

  unstub tar
}

@test 'uncompress with absolute path' {
  stub tar \
    "xzPf compressed \* : echo uncompressed \$2 into \$3"

  run uncompress compressed /tmp/tests/data/my_files

  assert_success
  assert_output --partial 'Cache is compressed, uncompressing with tgz...'

  unstub tar
}

@test 'compress with relative path' {
  stub tar \
    "czf compressed \* : echo uncompressed \$2 into \$3"

  run compress data/my_files compressed

  assert_success
  assert_output --partial 'Compressing data/my_files with tgz...'

  unstub tar
}

@test 'uncompress with relative path' {
  stub tar \
    "xzf compressed \* : echo uncompressed \$2 into \$3"

  run uncompress compressed data/my_files

  assert_success
  assert_output --partial 'Cache is compressed, uncompressing with tgz...'

  unstub tar
}
