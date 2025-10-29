#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export AWS_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_PLUGIN_S3_CACHE_BUCKET=my-bucket
}

# teardown() {
#   rm -rf "${BUILDKITE_PLUGIN_FS_CACHE_FOLDER}"
# }

@test 'Missing bucket configuration makes plugin fail' {
  unset BUILDKITE_PLUGIN_S3_CACHE_BUCKET

  run "${PWD}/backends/cache_s3"

  assert_failure
  assert_output --partial 'Missing S3 bucket configuration'
}

@test 'Invalid operation fails silently wtih 255' {
  run "${PWD}/backends/cache_s3" invalid

  assert_failure 255
  assert_output ''
}

@test 'Exists on empty file fails' {
  run "${PWD}/backends/cache_s3" exists ""

  assert_failure
  assert_output ''
}

@test 'Exists on non-existing file fails' {
  stub aws 'echo null'

  run "${PWD}/backends/cache_s3" exists PATH/THAT/DOES/NOT/EXIST

  assert_failure
  assert_output ''

  unstub aws
}

@test 'Exists on existing file/folder works' {
  stub aws 'echo "exists"'

  run "${PWD}/backends/cache_s3" exists existing

  assert_success
  assert_output ''

  unstub aws
}

@test 'Verbose flag passed when environment is set' {
  export BUILDKITE_PLUGIN_S3_CACHE_ONLY_SHOW_ERRORS=1
  stub aws \
    's3 sync --only-show-errors \* \* : echo ' \
    's3api head-object --bucket \* --key \* : false ' \
    's3 sync --only-show-errors \* \* : echo ' \
    's3api list-objects-v2 --bucket \* --prefix \* --max-items 1 --query Contents : echo exists'

  run "${PWD}/backends/cache_s3" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" get from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" exists to

  assert_success
  assert_output ''

  unstub aws
}

@test 'Endpoint URL flag passed when environment is set' {
  export BUILDKITE_PLUGIN_S3_CACHE_ENDPOINT=https://s3.somewhere.com

  stub aws \
    '--endpoint-url https://s3.somewhere.com s3 sync \* \* : echo ' \
    '--endpoint-url https://s3.somewhere.com s3api head-object --bucket \* --key \* : false ' \
    '--endpoint-url https://s3.somewhere.com s3 sync \* \* : echo ' \
    '--endpoint-url https://s3.somewhere.com s3api list-objects-v2 --bucket \* --prefix \* --max-items 1 --query Contents : echo exists'

  run "${PWD}/backends/cache_s3" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" get from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" exists to

  assert_success
  assert_output ''
}

@test 'Profile is passed when environment is set' {
  export BUILDKITE_PLUGIN_S3_CACHE_PROFILE=custom-profile

  stub aws \
    '--profile custom-profile s3 sync \* \* : echo ' \
    '--profile custom-profile s3api head-object --bucket \* --key \* : false ' \
    '--profile custom-profile s3 sync \* \* : echo ' \
    '--profile custom-profile s3api list-objects-v2 --bucket \* --prefix \* --max-items 1 --query Contents : echo exists' \

  run "${PWD}/backends/cache_s3" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" get from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" exists to

  assert_success
  assert_output ''

  unstub aws
}

@test 'File exists and can be restored after save' {
  touch "${BATS_TEST_TMPDIR}/new-file"
  mkdir "${BATS_TEST_TMPDIR}/s3-cache"
  stub aws \
    "echo null" \
    "s3 cp \* \* : ln -s \$3 $BATS_TEST_TMPDIR/s3-cache/\$(echo \$4 | md5sum | cut -c-32)" \
    "echo 'exists'" \
    's3api head-object --bucket \* --key \* : true ' \
    "s3 cp \* \* : cp -r $BATS_TEST_TMPDIR/s3-cache/\$(echo \$3 | md5sum | cut -c-32) \$4"

  run "${PWD}/backends/cache_s3" exists new-file

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_s3" save new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" exists new-file

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" get new-file "${BATS_TEST_TMPDIR}/other-file"

  assert_success
  assert_output ''

  diff "${BATS_TEST_TMPDIR}/new-file" "${BATS_TEST_TMPDIR}/other-file"

  unstub aws
  rm -rf "${BATS_TEST_TMPDIR}/s3-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-file"
}

@test 'Folder exists and can be restored after save' {
  mkdir "${BATS_TEST_TMPDIR}/s3-cache"
  mkdir "${BATS_TEST_TMPDIR}/new-folder"
  echo 'random content' > "${BATS_TEST_TMPDIR}/new-folder/new-file"

  stub aws \
    "echo null" \
    "s3 sync \* \* : ln -s \$3 $BATS_TEST_TMPDIR/s3-cache/\$(echo \$4 | md5sum | cut -c-32)" \
    "echo 'exists'" \
    's3api head-object --bucket \* --key \* : false ' \
    "s3 sync \* \* : cp -r $BATS_TEST_TMPDIR/s3-cache/\$(echo \$3 | md5sum | cut -c-32) \$4"

  run "${PWD}/backends/cache_s3" exists new-folder

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_s3" save new-folder "${BATS_TEST_TMPDIR}/new-folder"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" exists new-folder

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_s3" get new-folder "${BATS_TEST_TMPDIR}/other-folder"

  assert_success
  assert_output ''

  find "${BATS_TEST_TMPDIR}/new-folder"

  find "${BATS_TEST_TMPDIR}/other-folder"
  diff -r "${BATS_TEST_TMPDIR}/new-folder" "${BATS_TEST_TMPDIR}/other-folder"

  rm -rf "${BATS_TEST_TMPDIR}/s3-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-folder"
  rm -rf "${BATS_TEST_TMPDIR}/other-folder"
}
