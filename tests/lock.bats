#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"
  
  source "${PWD}/lib/lock.bash"
}

@test 'basic locking works as expected' {
  LOCKFILE="${BATS_TEST_TMPDIR}/lock.file"

  run lock "${LOCKFILE}"
  assert_success
  assert_output ''

  run lock "${LOCKFILE}"
  assert_failure
  assert_output ''

  run release_lock "${LOCKFILE}"
  assert_success
  assert_output ''

  run lock "${LOCKFILE}"
  assert_success
  assert_output ''

  rm -f "${LOCKFILE}"
}


@test 'lock times out' {
  LOCKFILE="${BATS_TEST_TMPDIR}/lock.file"

  run wait_and_lock "${LOCKFILE}"
  assert_success
  assert_output ''
  
  run wait_and_lock "${LOCKFILE}" 1
  assert_failure
  assert_equal "$(echo "${output}" | wc -l)" "1"

  run wait_and_lock "${LOCKFILE}"
  assert_failure
  assert_equal "$(echo "${output}" | wc -l)" "5"

  run release_lock "${LOCKFILE}"
  assert_success
  assert_output ''

  rm -f "${LOCKFILE}"
}