#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export CACHE_DUMMY_STUB_DEBUG=/dev/tty
# export TAR_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS=0

  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"
  echo "no alpacas" > "tests/data/my_files/alpacas.txt"

  export BUILDKITE_PLUGIN_CACHE_BACKEND=dummy
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=zstd
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/my_files

  # to make all test easier
  export BUILDKITE_PLUGIN_CACHE_FORCE=true

  # necessary for key-calculations
  export BUILDKITE_LABEL="step-label"
  export BUILDKITE_BRANCH="tests"
  export BUILDKITE_ORGANIZATION_SLUG="bk-cache-test"
  export BUILDKITE_PIPELINE_SLUG="cache-pipeline"

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  stub tar \
    "--help : echo '--zstd'" \
    "echo called tar with options \$@"
}

teardown() {
  rm -rf tests/data

  unstub cache_dummy
  unstub tar
}

@test "File-level saving with compression" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=tests/data/my_files/llamas.txt

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving file-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zstd'
  assert_output --partial "with options -c --zstd"
}

@test "Step-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=step

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving step-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zstd'
}

@test "Branch-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=branch

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving branch-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zstd'
}

@test "Pipeline-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=pipeline

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving pipeline-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zstd'
}

@test "All-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=all

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  assert_output --partial 'Compressing tests/data/my_files with zstd'
}

@test "Multiple level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE_0=all
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=pipeline

  # add an extra save, but tar should still be called only once
  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  assert_output --partial 'Saving pipeline-level cache'
}


@test 'Pipeline-level saving with absolute cache path' {
  BUILDKITE_PLUGIN_CACHE_PATH="$(mktemp -d)"
  export BUILDKITE_PLUGIN_CACHE_PATH
  export BUILDKITE_PLUGIN_CACHE_SAVE=pipeline

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving pipeline-level cache'
  assert_output --partial "Compressing ${BUILDKITE_PLUGIN_CACHE_PATH} with zstd..."
  assert_output --partial "with options -c --zstd -P"

  rm -rf "${BUILDKITE_PLUGIN_CACHE_PATH}"
}
