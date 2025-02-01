#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export HASH_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  source "${PWD}/lib/shared.bash"
}

teardown() {
  rm -rf test.file test.folder FOLDER FOLDER2
}

@test 'SHA is shasum1 if available' {
  skip 'builtins can not be stubbed'
  stub hash 'shasum1 : return 0'

  run "sha"

  assert_success
  assert_output 'shasum1'

  unstub hash
}

@test 'SHA is shasum if available' {
  skip 'builtins can not be stubbed'
  stub hash \
    'shasum1 : return 1' \
    'shasum : return 0'

  run "sha"

  assert_success
  #assert_output 'shasum'

  unstub hash
}

@test 'SHA is sha1sum if available' {
  skip 'builtins can not be stubbed'
  stub hash \
    'shasum1 : return 1' \
    'shasum : return 1' \
    'sha1sum : return 0'

  run "sha"

  assert_success
  assert_output 'sha1sum'

  unstub hash
}

@test 'file build_key when manifest is file works' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=test.file
  touch test.file

  run build_key file FOLDER

  assert_success

  EMPTY_FILE="${output}"

  # testing that changing what will be cached, changes the output
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

@test 'file build_key when manifest is folder works' {
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=test.folder
  mkdir test.folder

  run build_key file FOLDER

  assert_success

  EMPTY_FOLDER="${output}"
  echo With empty folder "$EMPTY_FOLDER"
  # testing that changing what will be cached, changes the output

  run build_key file FOLDER2

  assert_success
  refute_output "${EMPTY_FOLDER}"

  # changing the contents of the folder changes the output
  echo 'new_value' > test.folder/test.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  MODIFIED_FOLDER="${output}"

  # adding things outside the manifest does not change
  mkdir FOLDER
  touch FOLDER/test.file

  run build_key file FOLDER

  assert_success
  refute_output "${EMPTY_FOLDER}"
  assert_output "${MODIFIED_FOLDER}"

  rm -rf test.folder
  rm -rf FOLDER
}

@test 'build_key with compression changes' {
  run build_key file FOLDER

  assert_success
  EMPTY_KEY="${output}"

  run build_key file FOLDER ''
  assert_success
  assert_output "${EMPTY_KEY}"

  run build_key file FOLDER something

  assert_success
  GENERATED_KEY="${output}"

  run build_key file FOLDER another_thing
  assert_success
  refute_output "${GENERATED_KEY}"
}
