#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export GSUTIL_STUB_DEBUG=/dev/tty
# export GCLOUD_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_PLUGIN_GCS_CACHE_BUCKET=my-bucket
  # Force gsutil for testing unless explicitly testing gcloud
  export BUILDKITE_PLUGIN_GCS_CACHE_CLI=gsutil
}

# teardown() {
#   rm -rf "${BUILDKITE_PLUGIN_GCS_CACHE_FOLDER}"
# }

@test 'Missing bucket configuration makes plugin fail' {
  unset BUILDKITE_PLUGIN_GCS_CACHE_BUCKET

  run "${PWD}/backends/cache_gcs"

  assert_failure
  assert_output --partial 'Missing GCS bucket configuration'
}

@test 'Invalid operation fails silently with 255' {
  run "${PWD}/backends/cache_gcs" invalid

  assert_failure 255
  assert_output ''
}

@test 'Exists on empty file fails' {
  run "${PWD}/backends/cache_gcs" exists ""

  assert_failure
  assert_output ''
}

@test 'Exists on non-existing file fails' {
  stub gsutil 'ls \* : exit 1'

  run "${PWD}/backends/cache_gcs" exists PATH/THAT/DOES/NOT/EXIST

  assert_failure
  assert_output ''

  unstub gsutil
}

@test 'Exists on existing file/folder works' {
  stub gsutil 'ls \* : echo "gs://my-bucket/existing"'

  run "${PWD}/backends/cache_gcs" exists existing

  assert_success
  assert_output ''

  unstub gsutil
}

@test 'Quiet flag passed when environment is set' {
  export BUILDKITE_PLUGIN_GCS_CACHE_QUIET=1
  stub gsutil \
    '-q -m rsync -r -d \* \* : true ' \
    '-q ls \* : exit 1 ' \
    '-q -m rsync -r -d \* \* : true ' \
    '-m rsync -r -d \* \* : true ' \
    'ls \* : exit 1 ' \
    '-m rsync -r -d \* \* : true '

  run "${PWD}/backends/cache_gcs" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get from to

  assert_success
  assert_output ''

  unset BUILDKITE_PLUGIN_GCS_CACHE_QUIET

  run "${PWD}/backends/cache_gcs" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get from to

  assert_success
  assert_output ''

  unstub gsutil
}

@test 'File exists and can be restored after save' {
  touch "${BATS_TEST_TMPDIR}/new-file"
  mkdir "${BATS_TEST_TMPDIR}/gcs-cache"
  stub gsutil \
    "ls \* : exit 1" \
    "cp \* \* : ln -s \$2 $BATS_TEST_TMPDIR/gcs-cache/\$(echo \$3 | md5sum | cut -c-32)" \
    "ls \* : echo 'gs://my-bucket/new-file'" \
    'ls \* : exit 1 ' \
    "cp \* \* : cp -r $BATS_TEST_TMPDIR/gcs-cache/\$(echo \$2 | md5sum | cut -c-32) \$3"

  run "${PWD}/backends/cache_gcs" exists new-file

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_gcs" save new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" exists new-file

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get new-file "${BATS_TEST_TMPDIR}/other-file"

  assert_success
  assert_output ''

  diff "${BATS_TEST_TMPDIR}/new-file" "${BATS_TEST_TMPDIR}/other-file"

  unstub gsutil
  rm -rf "${BATS_TEST_TMPDIR}/gcs-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-file"
}

@test 'Folder exists and can be restored after save' {
  mkdir "${BATS_TEST_TMPDIR}/gcs-cache"
  mkdir "${BATS_TEST_TMPDIR}/new-folder"
  echo 'random content' > "${BATS_TEST_TMPDIR}/new-folder/new-file"

  stub gsutil \
    "ls \* : exit 1" \
    "-m rsync -r -d \* \* : ln -s \$4 $BATS_TEST_TMPDIR/gcs-cache/\$(echo \$5 | md5sum | cut -c-32)" \
    "ls \* : echo 'gs://my-bucket/new-folder'" \
    'ls \* : echo "gs://my-bucket/new-folder/"' \
    "-m rsync -r -d \* \* : cp -r $BATS_TEST_TMPDIR/gcs-cache/\$(echo \$4 | md5sum | cut -c-32) \$5"

  run "${PWD}/backends/cache_gcs" exists new-folder

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_gcs" save new-folder "${BATS_TEST_TMPDIR}/new-folder"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" exists new-folder

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get new-folder "${BATS_TEST_TMPDIR}/other-folder"

  assert_success
  assert_output ''

  find "${BATS_TEST_TMPDIR}/new-folder"

  find "${BATS_TEST_TMPDIR}/other-folder"
  diff -r "${BATS_TEST_TMPDIR}/new-folder" "${BATS_TEST_TMPDIR}/other-folder"

  rm -rf "${BATS_TEST_TMPDIR}/gcs-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-folder"
  rm -rf "${BATS_TEST_TMPDIR}/other-folder"
}

@test 'Prefix is used when environment is set' {
  export BUILDKITE_PLUGIN_GCS_CACHE_PREFIX=my-prefix

  stub gsutil \
    'ls gs://my-bucket/my-prefix/test-key\* : echo "gs://my-bucket/my-prefix/test-key"' \
    'ls gs://my-bucket/test-key\* : exit 1'

  run "${PWD}/backends/cache_gcs" exists test-key

  assert_success
  assert_output ''

  unset BUILDKITE_PLUGIN_GCS_CACHE_PREFIX

  run "${PWD}/backends/cache_gcs" exists test-key

  assert_failure
  assert_output ''

  unstub gsutil
}

@test 'gcloud storage CLI works when selected' {
  export BUILDKITE_PLUGIN_GCS_CACHE_CLI=gcloud

  stub gcloud \
    'storage --help : true' \
    'storage ls \* : echo "gs://my-bucket/existing"'

  run "${PWD}/backends/cache_gcs" exists existing

  assert_success
  assert_output ''

  unstub gcloud
}

@test 'gcloud storage quiet flag passed when environment is set' {
  export BUILDKITE_PLUGIN_GCS_CACHE_CLI=gcloud
  export BUILDKITE_PLUGIN_GCS_CACHE_QUIET=1

  stub gcloud \
    'storage --help : true' \
    'storage --verbosity=none rsync -r -d \* \* : echo ' \
    'storage --verbosity=none ls \* : exit 1 ' \
    'storage --verbosity=none rsync -r -d \* \* : echo ' \
    'storage rsync -r -d \* \* : echo ' \
    'storage ls \* : exit 1 ' \
    'storage rsync -r -d \* \* : echo '

  run "${PWD}/backends/cache_gcs" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get from to

  assert_success
  assert_output ''

  unset BUILDKITE_PLUGIN_GCS_CACHE_QUIET

  run "${PWD}/backends/cache_gcs" save from to

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get from to

  assert_success
  assert_output ''

  unstub gcloud
}

@test 'gcloud storage file operations work' {
  export BUILDKITE_PLUGIN_GCS_CACHE_CLI=gcloud
  touch "${BATS_TEST_TMPDIR}/new-file"
  mkdir "${BATS_TEST_TMPDIR}/gcs-cache"

  stub gcloud \
    'storage --help : true' \
    "storage ls \* : exit 1" \
    "storage cp \* \* : ln -s \$3 $BATS_TEST_TMPDIR/gcs-cache/\$(echo \$4 | md5sum | cut -c-32)" \
    "storage ls \* : echo 'gs://my-bucket/new-file'" \
    'storage ls \* : exit 1 ' \
    "storage cp \* \* : cp -r $BATS_TEST_TMPDIR/gcs-cache/\$(echo \$3 | md5sum | cut -c-32) \$4"

  run "${PWD}/backends/cache_gcs" exists new-file

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_gcs" save new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" exists new-file

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_gcs" get new-file "${BATS_TEST_TMPDIR}/other-file"

  assert_success
  assert_output ''

  diff "${BATS_TEST_TMPDIR}/new-file" "${BATS_TEST_TMPDIR}/other-file"

  unstub gcloud
  rm -rf "${BATS_TEST_TMPDIR}/gcs-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-file"
}