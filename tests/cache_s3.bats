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
    "s3api put-object --bucket \* --key \* --if-none-match \* --body \* : cp \${10} $BATS_TEST_TMPDIR/s3-cache/\$(echo s3://\$4/\$6 | md5sum | cut -c-32)" \
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

@test 'Single file save uses a conditional put-object' {
  touch "${BATS_TEST_TMPDIR}/file-to-save"

  stub aws \
    's3api put-object --bucket my-bucket --key \* --if-none-match \* --body \* : echo stored'

  run "${PWD}/backends/cache_s3" save my-key "${BATS_TEST_TMPDIR}/file-to-save"

  assert_success
  assert_output ''

  unstub aws
  rm -f "${BATS_TEST_TMPDIR}/file-to-save"
}

@test 'Single file save with force overwrites instead of conditional create' {
  export BUILDKITE_PLUGIN_CACHE_FORCE=true
  touch "${BATS_TEST_TMPDIR}/file-to-save"

  stub aws \
    's3 cp \* \* : echo copied'

  run "${PWD}/backends/cache_s3" save my-key "${BATS_TEST_TMPDIR}/file-to-save"

  assert_success

  unstub aws
  rm -f "${BATS_TEST_TMPDIR}/file-to-save"
  unset BUILDKITE_PLUGIN_CACHE_FORCE
}

@test 'Single file save treats PreconditionFailed as success (concurrent writer won)' {
  touch "${BATS_TEST_TMPDIR}/file-to-save"

  stub aws \
    's3api put-object --bucket my-bucket --key \* --if-none-match \* --body \* : echo "An error occurred (PreconditionFailed) when calling the PutObject operation" >&2; exit 1'

  run "${PWD}/backends/cache_s3" save my-key "${BATS_TEST_TMPDIR}/file-to-save"

  assert_success
  assert_output --partial 'Cache already saved by a concurrent job'

  unstub aws
  rm -f "${BATS_TEST_TMPDIR}/file-to-save"
}

@test 'Single file save falls back to copy when conditional put is unsupported' {
  touch "${BATS_TEST_TMPDIR}/file-to-save"

  stub aws \
    's3api put-object --bucket my-bucket --key \* --if-none-match \* --body \* : echo "Unknown options: --if-none-match" >&2; exit 255' \
    's3 cp \* \* : echo copied'

  run "${PWD}/backends/cache_s3" save my-key "${BATS_TEST_TMPDIR}/file-to-save"

  assert_success
  assert_output --partial 'falling back to copy'

  unstub aws
  rm -f "${BATS_TEST_TMPDIR}/file-to-save"
}

@test 'Restore retries when a download fails then succeeds' {
  export BUILDKITE_PLUGIN_S3_CACHE_DOWNLOAD_RETRIES=3

  stub sleep '1 : true'
  stub aws \
    's3api head-object --bucket \* --key \* : true ' \
    's3 cp \* \* : echo "did not match expected ETag" >&2; exit 1' \
    's3 cp \* \* : echo restored'

  run "${PWD}/backends/cache_s3" get my-key "${BATS_TEST_TMPDIR}/dest"

  assert_success
  assert_output --partial 'retrying'

  unstub aws
  unstub sleep
}

@test 'Restore fails after exhausting retries' {
  export BUILDKITE_PLUGIN_S3_CACHE_DOWNLOAD_RETRIES=2

  stub sleep '1 : true'
  stub aws \
    's3api head-object --bucket \* --key \* : true ' \
    's3 cp \* \* : echo "did not match expected ETag" >&2; exit 1' \
    's3 cp \* \* : echo "did not match expected ETag" >&2; exit 1'

  run "${PWD}/backends/cache_s3" get my-key "${BATS_TEST_TMPDIR}/dest"

  assert_failure

  unstub aws
  unstub sleep
}
