#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export HASH_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  source "${PWD}/lib/compression.bash"
}

@test 'validate_compression works' {
  run validate_compression none

  assert_success

  run validate_compression tgz
  assert_success

  run validate_compression zip
  assert_success

  run validate_compression invalid
  assert_failure
}
