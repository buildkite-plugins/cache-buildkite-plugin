#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export HASH_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  source "${PWD}/lib/shared.bash"
}

teardown() {
  rm -rf test.file other.file third.file test.folder other.folder FOLDER FOLDER2
}

@test 'file build_key when manifest is list with single file works' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.file
  touch test.file

  run build_key file FOLDER

  assert_success

  EMPTY_FILE="${output}"

  # changing what will be cached, changes the output
  run build_key file FOLDER2

  assert_success
  refute_output "${EMPTY_FILE}"

  # changing the manifest changes the output
  echo 'new_value' > test.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FILE}"
  MODIFIED_FILE="${output}"

  # adding things outside the manifest does not change
  mkdir FOLDER
  touch FOLDER/test.file
  touch other.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FILE}"
  assert_output "${MODIFIED_FILE}"

  rm test.file
  rm -rf FOLDER
  rm other.file
}

@test 'file build_key with multiple manifest files does not depend on order' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=other.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_2=third.file

  echo '1' > test.file
  echo '2' > other.file
  echo '3' > third.file

  run build_key file FOLDER
  EXPECTED="${output}"

  # change ordering
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=third.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_2=other.file

  run build_key file FOLDER
  assert_output "${EXPECTED}"

  # change ordering
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=other.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=test.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_2=third.file

  run build_key file FOLDER
  assert_output "${EXPECTED}"

  # change ordering
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=other.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=third.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_2=test.file

  run build_key file FOLDER
  assert_output "${EXPECTED}"

  # change ordering
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=third.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=test.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_2=other.file

  run build_key file FOLDER
  assert_output "${EXPECTED}"

  # change ordering
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=third.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=other.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_2=test.file

  run build_key file FOLDER
  assert_output "${EXPECTED}"

  rm test.file
  rm other.file
  rm third.file
}

@test 'file build_key with multiple manifest files works' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=other.file

  touch test.file
  touch other.file

  run build_key file FOLDER

  assert_success

  EMPTY_FILE="${output}"

  # changing what will be cached, changes the output
  run build_key file FOLDER2

  assert_success
  refute_output "${EMPTY_FILE}"

  # changing the manifest in one file changes the output
  echo 'new_value' > test.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FILE}"
  MODIFIED_FILE_1="${output}"

  # adding things outside the manifest does not change
  mkdir FOLDER
  touch FOLDER/test.file
  touch other.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FILE}"
  assert_output "${MODIFIED_FILE_1}"

  # changing the manifest in the other file changes the output
  rm test.file && touch test.file # restoring the original test.file
  echo 'other_value' > other.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FILE}"
  refute_output "${MODIFIED_FILE_1}"

  rm test.file
  rm -rf FOLDER
  rm other.file
}

@test 'file build_key with multiple manifest files & folders works' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.folder
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=test.file

  mkdir test.folder
  touch test.file

  run build_key file FOLDER

  assert_success
  EMPTY_FOLDER="${output}"

  # changing what will be cached, changes the output
  run build_key file FOLDER2

  assert_success
  refute_output "${EMPTY_FOLDER}"

  # changing the ordering does not change the output
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=test.folder

  run build_key file FOLDER

  assert_success
  assert_output "${EMPTY_FOLDER}"

  # changing the contents of the folder changes the output
  echo 'new_value' > test.folder/test.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  MODIFIED_FOLDER="${output}"

  # adding things outside the manifest does not change
  mkdir FOLDER
  touch FOLDER/test.file
  touch other.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  assert_output "${MODIFIED_FOLDER}"

  rm -rf test.folder
  rm test.file
  rm other.file
  rm -rf FOLDER
}


@test 'file build_key with multiple manifest folders works' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=test.folder
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=other.folder

  mkdir test.folder
  mkdir other.folder
  echo '1' > other.folder/test.file

  run build_key file FOLDER

  assert_success
  EMPTY_FOLDER="${output}"

  # changing what will be cached, changes the output
  run build_key file FOLDER2

  assert_success
  refute_output "${EMPTY_FOLDER}"

  # changing the ordering does not change the output
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_0=other.folder
  export BUILDKITE_PLUGIN_CACHE_MANIFEST_1=test.folder

  run build_key file FOLDER

  assert_success
  assert_output "${EMPTY_FOLDER}"

  # changing the contents of the folder changes the output
  echo 'new_value' > test.folder/test.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  MODIFIED_FOLDER="${output}"

  # adding things outside the manifest does not change
  mkdir FOLDER
  touch FOLDER/test.file
  touch other.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  assert_output "${MODIFIED_FOLDER}"

  # removing something from the folder changes the output
  rm other.folder/test.file
  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  refute_output "${MODIFIED_FOLDER}"

  rm -rf test.folder
  rm -rf other.folder
  rm other.file
  rm -rf FOLDER
}
