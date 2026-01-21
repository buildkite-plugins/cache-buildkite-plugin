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

@test 'cleanup_compression_tempfile works' {
  touch temp_file

  # by default it removes the file
  run cleanup_compression_tempfile temp_file
  assert_success
  assert [ ! -e  temp_file ]

  # if we want to keep the file, it should not be removed
  export BUILDKITE_PLUGIN_CACHE_KEEP_COMPRESSED_ARTIFACTS=true
  touch temp_file

  run cleanup_compression_tempfile temp_file
  assert_success
  assert [ -e  temp_file ]

  # but we can also ask specifically to have it removed
  export BUILDKITE_PLUGIN_CACHE_KEEP_COMPRESSED_ARTIFACTS=false

  run cleanup_compression_tempfile temp_file
  assert_success
  assert [ ! -e  temp_file ]
}

@test 'zstd_wrapper uses --zstd when tar supports it' {
  stub tar \
    "--help : echo '--zstd'" \
    "-c --zstd -f \* \* : echo compressed with native zstd"

  run "${PWD}/compression/zstd_wrapper" compress source target
  assert_success
  assert_output --partial "compressed with native zstd"

  unstub tar
}

@test 'zstd_wrapper falls back to --use-compress-program=zstd when tar does not support --zstd' {
  # Create a fake zstd binary for command -v to find
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  touch "${BATS_TEST_TMPDIR}/bin/zstd"
  chmod +x "${BATS_TEST_TMPDIR}/bin/zstd"

  stub tar \
    "--help : echo 'no zstd support here'" \
    "-c --use-compress-program=zstd -f \* \* : echo compressed with external zstd"

  run env PATH="${BATS_TEST_TMPDIR}/bin:${BATS_MOCK_BINDIR}:${PATH}" "${PWD}/compression/zstd_wrapper" compress source target
  assert_success
  assert_output --partial "compressed with external zstd"

  unstub tar
}

@test 'zstd_wrapper decompress falls back to --use-compress-program=zstd' {
  # Create a fake zstd binary for command -v to find
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  touch "${BATS_TEST_TMPDIR}/bin/zstd"
  chmod +x "${BATS_TEST_TMPDIR}/bin/zstd"

  stub tar \
    "--help : echo 'no zstd support here'" \
    "-x --use-compress-program=zstd -f \* \* : echo decompressed with external zstd"

  run env PATH="${BATS_TEST_TMPDIR}/bin:${BATS_MOCK_BINDIR}:${PATH}" "${PWD}/compression/zstd_wrapper" decompress source target
  assert_success
  assert_output --partial "decompressed with external zstd"

  unstub tar
}

@test 'zstd_wrapper fails when neither tar --zstd nor zstd binary available' {
  stub tar \
    "--help : echo 'no zstd support here'"

  # Use PATH with mock bindir (for tar stub) and essential utils, but no zstd
  run env PATH="${BATS_MOCK_BINDIR}:/usr/bin:/bin" "${PWD}/compression/zstd_wrapper" compress source target
  assert_failure
  assert_output --partial "zstd compression is not available"
  assert_output --partial "Either upgrade tar to 1.31+ (with --zstd support) or install the zstd binary"

  unstub tar
}
