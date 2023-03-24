#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export CP_DUMMY_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_PLUGIN_FS_CACHE_FOLDER=/tmp/fs-test
  mkdir -p "${BUILDKITE_PLUGIN_FS_CACHE_FOLDER}"
  touch "${BUILDKITE_PLUGIN_FS_CACHE_FOLDER}/existing_file"
  mkdir "${BUILDKITE_PLUGIN_FS_CACHE_FOLDER}/existing_folder"
}

teardown() {
  rm -rf "${BUILDKITE_PLUGIN_FS_CACHE_FOLDER}"
}

@test 'Invalid operation fails silently wtih 255' {
  run "${PWD}/backends/cache_fs" invalid

  assert_failure 255
  assert_output ''
}

@test 'Exists on non-existing file fails' {
  run "${PWD}/backends/cache_fs" exists PATH/THAT/DOES/NOT/EXIST

  assert_failure
  assert_output ''
}

@test 'Exists on empty file fails' {
  run "${PWD}/backends/cache_fs" exists ""

  assert_failure
  assert_output ''
}

@test 'Exists on existing folder works' {
  run "${PWD}/backends/cache_fs" exists existing_folder 

  assert_success
  assert_output ''
}

@test 'File exists and can be restored after save' {
  touch "${BATS_TEST_TMPDIR}/new-file"

  run "${PWD}/backends/cache_fs" exists new-file
  
  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_fs" save new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_fs" exists new-file

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_fs" get new-file "${BATS_TEST_TMPDIR}/other-file"
  assert_success
  assert_output ''

  diff "${BATS_TEST_TMPDIR}/new-file" "${BATS_TEST_TMPDIR}/other-file"
}

@test 'Folder exists and can be restored after save' {
  mkdir "${BATS_TEST_TMPDIR}/new-folder"
  echo 'random content' > "${BATS_TEST_TMPDIR}/new-folder/new-file"

  run "${PWD}/backends/cache_fs" exists new-folder
  
  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_fs" save new-folder "${BATS_TEST_TMPDIR}/new-folder"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_fs" exists new-folder

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_fs" get new-folder "${BATS_TEST_TMPDIR}/other-folder"

  assert_success
  assert_output ''

  find "${BATS_TEST_TMPDIR}/new-folder"

  find "${BATS_TEST_TMPDIR}/other-folder"
  diff -r "${BATS_TEST_TMPDIR}/new-folder" "${BATS_TEST_TMPDIR}/other-folder"
}
