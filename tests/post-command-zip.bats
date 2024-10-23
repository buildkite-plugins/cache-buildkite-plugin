#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export CACHE_DUMMY_STUB_DEBUG=/dev/tty
# export ZIP_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS=0

  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"
  echo "no alpacas" > "tests/data/my_files/alpacas.txt"

  export BUILDKITE_PLUGIN_CACHE_BACKEND=dummy
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=zip
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/my_files

  # to make all test easier
  export BUILDKITE_PLUGIN_CACHE_FORCE=true

  # necessary for key-calculations
  export BUILDKITE_LABEL="step-label"
  export BUILDKITE_BRANCH="tests"
  export BUILDKITE_ORGANIZATION_SLUG="bk-cache-test"
  export BUILDKITE_PIPELINE_SLUG="cache-pipeline"

  # stubs are the same for every test
  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  # if the file is not created, this fails because zip
  stub zip \
    "touch \$2; echo compressed \${@:3} into \$2"
}

teardown() {
  rm -rf tests/data

  unstub cache_dummy
  unstub zip
}

@test "File-level saving with compression" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=tests/data/my_files/llamas.txt

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving file-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zip'
}

@test "Step-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=step

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving step-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zip'
}

@test "Branch-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=branch

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving branch-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zip'
}

@test "Pipeline-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=pipeline

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving pipeline-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zip'
}

@test "All-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=all

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zip'
}

@test "Multiple level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE_0=all
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=pipeline

  # add an extra save, but zip should still be called only once
  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  assert_output --partial 'Saving pipeline-level cache'
}

@test 'Pipeline-level saving with absolute cache path' {
  mkdir -p /tmp/tests/data/my_files
  export BUILDKITE_PLUGIN_CACHE_PATH=/tmp/tests/data/my_files
  export BUILDKITE_PLUGIN_CACHE_SAVE=pipeline

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Compressing /tmp/tests/data/my_files with zip...'
  assert_output --partial 'Saving pipeline-level cache'

  rm -rf /tmp/tests/data/my_files
}

