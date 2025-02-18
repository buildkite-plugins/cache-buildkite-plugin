#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export CACHE_DUMMY_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS=0

  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"
  echo "no alpacas" > "tests/data/my_files/alpacas.txt"

  export BUILDKITE_PLUGIN_CACHE_BACKEND=dummy
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/my_files

  # to make all test easier
  export BUILDKITE_PLUGIN_CACHE_FORCE=true

  # necessary for key-calculations
  export BUILDKITE_LABEL="step-label"
  export BUILDKITE_BRANCH="tests"
  export BUILDKITE_ORGANIZATION_SLUG="bk-cache-test"
  export BUILDKITE_PIPELINE_SLUG="cache-pipeline"
}

teardown() {
  rm -rf tests/data
}

@test 'If not setup for saving, do nothing' {
  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Cache not setup for saving'
}

@test 'If command failed, do nothing' {
  export BUILDKITE_COMMAND_EXIT_STATUS=127

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Aborting cache post-command hook because command exited with status 127'
}

@test "Missing path fails" {
  unset BUILDKITE_PLUGIN_CACHE_PATH

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial 'Missing path option'
}

@test "Invalid level fails" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=unreal

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial 'Invalid levels in the save list'
}

@test "File-based cache with no manifest fails" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=file

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial 'Missing manifest option'
}

@test "File-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=file
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=tests/data/my_files/llamas.txt

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving file-level cache'

  unstub cache_dummy
}

@test "Step-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=step

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving step-level cache'

  unstub cache_dummy
}

@test "Branch-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=branch

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving branch-level cache'

  unstub cache_dummy
}

@test "Pipeline-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=pipeline

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving pipeline-level cache'

  unstub cache_dummy
}

@test "All-level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=all

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'

  unstub cache_dummy
}

@test "Multiple level saving" {
  export BUILDKITE_PLUGIN_CACHE_SAVE_0=all
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=pipeline

  stub cache_dummy \
    "save \* \* : echo saving \$3 in \$2" \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  assert_output --partial 'Saving pipeline-level cache'

  unstub cache_dummy
}

@test "Multiple level file without manifest fails" {
  export BUILDKITE_PLUGIN_CACHE_SAVE_0=all
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=file

  run "$PWD/hooks/post-command"

  assert_failure

  assert_output --partial 'Missing manifest option'
  refute_output --partial 'Saving file-level cache'
}

@test "Multiple level containing invalid one fails" {
  export BUILDKITE_PLUGIN_CACHE_SAVE_0=pipeline
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=unreal

  run "$PWD/hooks/post-command"

  assert_failure

  assert_output --partial 'Invalid levels in the save list'
  refute_output --partial 'Saving pipeline-level cache'
}

@test "Saving is skipped when cache exists" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=all
  export BUILDKITE_PLUGIN_CACHE_FORCE='false'

  stub cache_dummy \
    "exists \* \* : exit 0"

  run "$PWD/hooks/post-command"

  assert_success
  refute_output --partial 'Saving all-level cache'

  unstub cache_dummy
}

@test "Multiple level saving not forced" {
  export BUILDKITE_PLUGIN_CACHE_FORCE=false

  export BUILDKITE_PLUGIN_CACHE_SAVE_0=all
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=pipeline

  stub cache_dummy \
    "exists \* \* : exit 0" \
    "exists \* \* : exit 1" \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  refute_output --partial 'Saving pipeline-level cache'

  unstub cache_dummy
}

@test "Multiple level saving lower level change forces higher levels" {
  export BUILDKITE_PLUGIN_CACHE_FORCE=false

  export BUILDKITE_PLUGIN_CACHE_SAVE_0=all
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=pipeline
  export BUILDKITE_PLUGIN_CACHE_SAVE_2=step

  stub cache_dummy \
    "exists \* \* : exit 0" \
    "exists \* \* : exit 1" \
    "save \* \* : echo saving \$3 in \$2" \
    "save \* \* : echo saving \$3 in \$2"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Saving all-level cache'
  assert_output --partial 'Saving pipeline-level cache'
  refute_output --partial 'Saving step-level cache'

  unstub cache_dummy
}
