#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export AZ_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_PLUGIN_AZURE_CACHE_CONTAINER=my-container
  export BUILDKITE_PLUGIN_AZURE_CACHE_ACCOUNT=mystorageaccount
}

@test 'Missing container configuration makes plugin fail' {
  unset BUILDKITE_PLUGIN_AZURE_CACHE_CONTAINER

  run "${PWD}/backends/cache_azure"

  assert_failure
  assert_output --partial 'Missing Azure container configuration'
}

@test 'Missing account configuration makes plugin fail' {
  unset BUILDKITE_PLUGIN_AZURE_CACHE_ACCOUNT

  run "${PWD}/backends/cache_azure"

  assert_failure
  assert_output --partial 'Missing Azure storage account configuration'
}

@test 'Invalid operation fails silently with 255' {
  run "${PWD}/backends/cache_azure" invalid

  assert_failure 255
  assert_output ''
}

@test 'Exists on empty file fails' {
  run "${PWD}/backends/cache_azure" exists ""

  assert_failure
  assert_output ''
}

@test 'Exists on non-existing file fails' {
  stub az \
    'storage blob show --account-name \* --container-name \* --name \* : exit 1' \
    'storage blob list --container-name \* --account-name \* --prefix \* --num-results 1 --query \[0\].name --output tsv : echo ""'

  run "${PWD}/backends/cache_azure" exists PATH/THAT/DOES/NOT/EXIST

  assert_failure
  assert_output ''

  unstub az
}

@test 'Save fails with clear error when source path does not exist' {
  run "${PWD}/backends/cache_azure" save cache-key /path/that/does/not/exist

  assert_failure
  assert_output --partial 'Cache source path does not exist'
}

@test 'Exists on existing file/folder works' {
  stub az \
    'storage blob show --account-name \* --container-name \* --name \* : true'

  run "${PWD}/backends/cache_azure" exists existing

  assert_success
  assert_output ''

  unstub az
}

@test 'Quiet flag passed when environment is set' {
  export BUILDKITE_PLUGIN_AZURE_CACHE_QUIET=1
  touch "${BATS_TEST_TMPDIR}/test-file"

  stub az \
    'storage blob upload --account-name \* --no-progress --only-show-errors --container-name \* --name \* --file \* --overwrite : true' \
    'storage blob show --account-name \* --only-show-errors --container-name \* --name \* : true' \
    'storage blob download --account-name \* --no-progress --only-show-errors --container-name \* --name \* --file \* : true' \
    'storage blob show --account-name \* --only-show-errors --container-name \* --name \* : true' \
    'storage blob upload --account-name \* --container-name \* --name \* --file \* --overwrite : true' \
    'storage blob show --account-name \* --container-name \* --name \* : true' \
    'storage blob download --account-name \* --container-name \* --name \* --file \* : true' \
    'storage blob show --account-name \* --container-name \* --name \* : true'

  run "${PWD}/backends/cache_azure" save from "${BATS_TEST_TMPDIR}/test-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get from "${BATS_TEST_TMPDIR}/test-file-restored"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" exists from

  assert_success
  assert_output ''

  unset BUILDKITE_PLUGIN_AZURE_CACHE_QUIET

  run "${PWD}/backends/cache_azure" save from "${BATS_TEST_TMPDIR}/test-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get from "${BATS_TEST_TMPDIR}/test-file-restored-2"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" exists from

  assert_success
  assert_output ''

  unstub az
  rm -f "${BATS_TEST_TMPDIR}/test-file"
  rm -f "${BATS_TEST_TMPDIR}/test-file-restored"
  rm -f "${BATS_TEST_TMPDIR}/test-file-restored-2"
}

@test 'Auth mode flag passed when environment is set (login)' {
  export BUILDKITE_PLUGIN_AZURE_CACHE_AUTH_MODE=login
  touch "${BATS_TEST_TMPDIR}/test-file"

  stub az \
    'storage blob upload --account-name \* --auth-mode login --container-name \* --name \* --file \* --overwrite : true' \
    'storage blob show --account-name \* --auth-mode login --container-name \* --name \* : true' \
    'storage blob download --account-name \* --auth-mode login --container-name \* --name \* --file \* : true'

  run "${PWD}/backends/cache_azure" save from "${BATS_TEST_TMPDIR}/test-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get from "${BATS_TEST_TMPDIR}/test-file-restored"

  assert_success
  assert_output ''

  unstub az
  rm -f "${BATS_TEST_TMPDIR}/test-file"
  rm -f "${BATS_TEST_TMPDIR}/test-file-restored"
}

@test 'Storage account key auth mode works' {
  export BUILDKITE_PLUGIN_AZURE_CACHE_AUTH_MODE=key
  export AZURE_STORAGE_KEY=fake-storage-key
  touch "${BATS_TEST_TMPDIR}/test-file"

  stub az \
    'storage blob upload --account-name \* --auth-mode key --account-key fake-storage-key --container-name \* --name \* --file \* --overwrite : true' \
    'storage blob show --account-name \* --auth-mode key --account-key fake-storage-key --container-name \* --name \* : true' \
    'storage blob download --account-name \* --auth-mode key --account-key fake-storage-key --container-name \* --name \* --file \* : true'

  run "${PWD}/backends/cache_azure" save from "${BATS_TEST_TMPDIR}/test-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get from "${BATS_TEST_TMPDIR}/test-file-restored"

  assert_success
  assert_output ''

  unstub az
  unset AZURE_STORAGE_KEY
  rm -f "${BATS_TEST_TMPDIR}/test-file"
  rm -f "${BATS_TEST_TMPDIR}/test-file-restored"
}

@test 'Storage account key auth mode works with folders' {
  export BUILDKITE_PLUGIN_AZURE_CACHE_AUTH_MODE=key
  export AZURE_STORAGE_KEY=fake-storage-key
  mkdir "${BATS_TEST_TMPDIR}/azure-cache"
  mkdir "${BATS_TEST_TMPDIR}/test-folder"
  echo 'test content' > "${BATS_TEST_TMPDIR}/test-folder/test-file"

  stub az \
    "storage blob show --account-name \* --auth-mode key --account-key fake-storage-key --container-name \* --name \* : exit 1" \
    "storage blob list --container-name \* --account-name \* --prefix \* --num-results 1 --query \[0\].name --output tsv --auth-mode key --account-key fake-storage-key : echo ''" \
    "storage blob upload-batch --account-name \* --destination \* --source \* --destination-path \* --overwrite --auth-mode key --account-key fake-storage-key : cp -r \$9 $BATS_TEST_TMPDIR/azure-cache/\$(echo \${11} | md5sum | cut -c-32)" \
    "storage blob show --account-name \* --auth-mode key --account-key fake-storage-key --container-name \* --name \* : true" \
    "storage blob show --account-name \* --auth-mode key --account-key fake-storage-key --container-name \* --name \* : exit 1" \
    "storage blob download-batch --account-name \* --source \* --destination \* --pattern \* --auth-mode key --account-key fake-storage-key : cp -r $BATS_TEST_TMPDIR/azure-cache/\$(echo \${11} | sed 's|/\*||' | md5sum | cut -c-32) \$9"

  run "${PWD}/backends/cache_azure" exists test-folder

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_azure" save test-folder "${BATS_TEST_TMPDIR}/test-folder"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" exists test-folder

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get test-folder "${BATS_TEST_TMPDIR}/other-folder"

  assert_success
  assert_output ''

  diff -r "${BATS_TEST_TMPDIR}/test-folder" "${BATS_TEST_TMPDIR}/other-folder"

  unstub az
  unset AZURE_STORAGE_KEY
  rm -rf "${BATS_TEST_TMPDIR}/azure-cache"
  rm -rf "${BATS_TEST_TMPDIR}/test-folder"
  rm -rf "${BATS_TEST_TMPDIR}/other-folder"
}

@test 'File exists and can be restored after save' {
  touch "${BATS_TEST_TMPDIR}/new-file"
  mkdir "${BATS_TEST_TMPDIR}/azure-cache"

  stub az \
    "storage blob show --account-name \* --container-name \* --name \* : exit 1" \
    "storage blob list --container-name \* --account-name \* --prefix \* --num-results 1 --query \[0\].name --output tsv : echo ''" \
    "storage blob upload --account-name \* --container-name \* --name \* --file \* --overwrite : cp \${11} $BATS_TEST_TMPDIR/azure-cache/\$(echo \$9 | md5sum | cut -c-32)" \
    "storage blob show --account-name \* --container-name \* --name \* : true" \
    "storage blob show --account-name \* --container-name \* --name \* : true" \
    "storage blob download --account-name \* --container-name \* --name \* --file \* : cp $BATS_TEST_TMPDIR/azure-cache/\$(echo \$9 | md5sum | cut -c-32) \${11}"

  run "${PWD}/backends/cache_azure" exists new-file

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_azure" save new-file "${BATS_TEST_TMPDIR}/new-file"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" exists new-file

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get new-file "${BATS_TEST_TMPDIR}/other-file"

  assert_success
  assert_output ''

  diff "${BATS_TEST_TMPDIR}/new-file" "${BATS_TEST_TMPDIR}/other-file"

  unstub az
  rm -rf "${BATS_TEST_TMPDIR}/azure-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-file"
  rm -rf "${BATS_TEST_TMPDIR}/other-file"
}

@test 'Folder exists and can be restored after save' {
  mkdir "${BATS_TEST_TMPDIR}/azure-cache"
  mkdir "${BATS_TEST_TMPDIR}/new-folder"
  echo 'random content' > "${BATS_TEST_TMPDIR}/new-folder/new-file"

  stub az \
    "storage blob show --account-name \* --container-name \* --name \* : exit 1" \
    "storage blob list --container-name \* --account-name \* --prefix \* --num-results 1 --query \[0\].name --output tsv : echo ''" \
    "storage blob upload-batch --account-name \* --destination \* --source \* --destination-path \* --overwrite : cp -r \$9 $BATS_TEST_TMPDIR/azure-cache/\$(echo \${11} | md5sum | cut -c-32)" \
    "storage blob show --account-name \* --container-name \* --name \* : true" \
    "storage blob show --account-name \* --container-name \* --name \* : exit 1" \
    "storage blob download-batch --account-name \* --source \* --destination \* --pattern \* : cp -r $BATS_TEST_TMPDIR/azure-cache/\$(echo \${11} | sed 's|/\*||' | md5sum | cut -c-32) \$9"

  run "${PWD}/backends/cache_azure" exists new-folder

  assert_failure
  assert_output ''

  run "${PWD}/backends/cache_azure" save new-folder "${BATS_TEST_TMPDIR}/new-folder"

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" exists new-folder

  assert_success
  assert_output ''

  run "${PWD}/backends/cache_azure" get new-folder "${BATS_TEST_TMPDIR}/other-folder"

  assert_success
  assert_output ''

  find "${BATS_TEST_TMPDIR}/new-folder"

  find "${BATS_TEST_TMPDIR}/other-folder"
  diff -r "${BATS_TEST_TMPDIR}/new-folder" "${BATS_TEST_TMPDIR}/other-folder"

  unstub az
  rm -rf "${BATS_TEST_TMPDIR}/azure-cache"
  rm -rf "${BATS_TEST_TMPDIR}/new-folder"
  rm -rf "${BATS_TEST_TMPDIR}/other-folder"
}

@test 'Prefix is used when environment is set' {
  export BUILDKITE_PLUGIN_AZURE_CACHE_PREFIX=my-prefix

  stub az \
    'storage blob show --account-name \* --container-name \* --name my-prefix/test-key : true' \
    'storage blob show --account-name \* --container-name \* --name test-key : exit 1' \
    'storage blob list --container-name \* --account-name \* --prefix test-key/ --num-results 1 --query \[0\].name --output tsv : echo ""'

  run "${PWD}/backends/cache_azure" exists test-key

  assert_success
  assert_output ''

  unset BUILDKITE_PLUGIN_AZURE_CACHE_PREFIX

  run "${PWD}/backends/cache_azure" exists test-key

  assert_failure
  assert_output ''

  unstub az
}

@test 'Account name is passed correctly' {
  export BUILDKITE_PLUGIN_AZURE_CACHE_ACCOUNT=myaccount

  stub az \
    'storage blob show --account-name myaccount --container-name \* --name \* : true'

  run "${PWD}/backends/cache_azure" exists test-key

  assert_success
  assert_output ''

  unstub az
}
