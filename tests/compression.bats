#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export DUMMY_COMPRESS_WRAPPER_STUB_DEBUG=/dev/tty
# export DUMMY_DECOMPRESS_WRAPPER_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # prevent a warning when using flags on run
  bats_require_minimum_version 1.5.0

  source "${PWD}/lib/compression.bash"
}

# TODO: Add tests for wrappers
#TODO: change plugin.yml and README

@test 'compression_active works' {
  # default value
  run compression_active
  assert_failure

  # turned off
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=none
  run compression_active
  assert_failure

  # any other value
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=something_else
  run compression_active
  assert_success
}

@test 'compress works' {
  # default value does nothing
  run compress SOURCE TARGET
  assert_success
  refute_output 'Compressiong SOURCE with'

  # define a compression
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=dummy_compress
  # -127 prevents a warning due to command not found
  run -127 compress SOURCE TARGET
  assert_failure
  assert_output --partial 'Compressing SOURCE with dummy_compress'
  assert_output --partial 'dummy_compress_wrapper: command not found'

  # using an existing compression
  stub dummy_compress_wrapper \
    "compress \* \* : echo Compressed wrapper \$2 with dummy_compress"

  run compress SOURCE TARGET
  assert_success
  assert_output --partial 'Compressing SOURCE with dummy_compress'

  unstub dummy_compress_wrapper
}

@test 'decompress works' {
  # default value does nothing
  run decompress SOURCE TARGET
  assert_success
  refute_output 'uncompressing with'

  # define a compression
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=dummy_decompress
  # -127 prevents a warning due to command not found
  run -127 decompress SOURCE TARGET
  assert_failure
  assert_output --partial 'decompressing with dummy_decompress'
  assert_output --partial 'dummy_decompress_wrapper: command not found'

  # using an existing compression
  stub dummy_decompress_wrapper \
    "decompress \* \* : echo Decompressing wrapper \$2 with dummy_decompress"

  run decompress SOURCE TARGET
  assert_success
  assert_output --partial 'decompressing with dummy_decompress'

  unstub dummy_decompress_wrapper
}
