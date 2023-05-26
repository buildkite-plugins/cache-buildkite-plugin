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

  run "${PWD}/backends/cache_tar_s3"

  assert_failure
  assert_output --partial 'Missing S3 bucket configuration'
}

@test 'Invalid operation fails silently with 255' {
  run "${PWD}/backends/cache_tar_s3" invalid

  assert_failure 255
  assert_output ''
}

@test 'Exists on empty file fails' {
  run "${PWD}/backends/cache_tar_s3" exists ""

  assert_failure
  assert_output ''
}

@test 'Exists on non-existing file fails' {
  stub aws 'exit 1'

  run "${PWD}/backends/cache_tar_s3" exists PATH/THAT/DOES/NOT/EXIST

  assert_failure
  assert_output ''

  unstub aws
}

@test 'Exists on existing file/folder works' {
  stub aws 'echo "existing"'

  run "${PWD}/backends/cache_tar_s3" exists existing

  assert_success
  assert_output ''

  unstub aws
}

@test 'missing from file/folder works' {

  run "${PWD}/backends/cache_tar_s3" save missing "missing"

  assert_success
  assert_output 'no file(s) to cache found at: missing'
}

@test 'File exists and can be restored after save' {
  echo "content" > "${BATS_TEST_TMPDIR}/new-file"
  mkdir "${BATS_TEST_TMPDIR}/s3-cache"

  stub aws \
    "test -e $BATS_TEST_TMPDIR/s3-cache/\$(echo s3://\$4/\$6 | md5sum | cut -c-32)" \
    "s3 cp cache.tar.gz \* \* : cp $PWD/\$3 $BATS_TEST_TMPDIR/s3-cache/\$(echo \$4 | md5sum | cut -c-32)" \
    "echo found" \
    "cp $BATS_TEST_TMPDIR/s3-cache/\$(echo \$3 | md5sum | cut -c-32) $PWD/cache.tar.gz"

  run "${PWD}/backends/cache_tar_s3" exists new-file

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_tar_s3" save new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  mv "${BATS_TEST_TMPDIR}/new-file" "${BATS_TEST_TMPDIR}/original-file"

  run "${PWD}/backends/cache_tar_s3" exists new-file

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_tar_s3" get new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  diff "${BATS_TEST_TMPDIR}/original-file" "${BATS_TEST_TMPDIR}/new-file"

  unstub aws
  rm -rf "${BATS_TEST_TMPDIR}/s3-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-file"
}

@test 'Folder exists and can be restored after save' {
  mkdir "${BATS_TEST_TMPDIR}/s3-cache"
  mkdir "${BATS_TEST_TMPDIR}/new-folder"
  echo 'random content' > "${BATS_TEST_TMPDIR}/new-folder/new-file"

  stub aws \
    "test -e $BATS_TEST_TMPDIR/s3-cache/\$(echo s3://\$4/\$6 | md5sum | cut -c-32)" \
    "s3 cp cache.tar.gz \* \* : cp $PWD/\$3 $BATS_TEST_TMPDIR/s3-cache/\$(echo \$4 | md5sum | cut -c-32)" \
    "echo found" \
    "cp $BATS_TEST_TMPDIR/s3-cache/\$(echo \$3 | md5sum | cut -c-32) $PWD/cache.tar.gz"

  run "${PWD}/backends/cache_tar_s3" exists new-folder

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_tar_s3" save new-folder "${BATS_TEST_TMPDIR}/new-folder"

  assert_success
  assert_output ''

  mv "${BATS_TEST_TMPDIR}/new-folder" "${BATS_TEST_TMPDIR}/original-folder"

  run "${PWD}/backends/cache_tar_s3" exists new-folder

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_tar_s3" get new-folder "${BATS_TEST_TMPDIR}/new-folder"

  assert_success
  assert_output ''

  find "${BATS_TEST_TMPDIR}/original-folder"

  find "${BATS_TEST_TMPDIR}/new-folder"
  diff -r "${BATS_TEST_TMPDIR}/original-folder" "${BATS_TEST_TMPDIR}/new-folder"

  rm -rf "${BATS_TEST_TMPDIR}/s3-cache"
  rm -rf "${BATS_TEST_TMPDIR}/original-folder"
  rm -rf "${BATS_TEST_TMPDIR}/new-folder"
}
