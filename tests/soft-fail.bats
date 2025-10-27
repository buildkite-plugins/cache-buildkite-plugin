#!/usr/bin/env bats

# Tests for the soft-fail option feature
# This feature allows cache operations to fail gracefully without blocking the build

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS=0

  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"
  echo "no alpacas" > "tests/data/my_files/alpacas.txt"

  export BUILDKITE_PLUGIN_CACHE_BACKEND=dummy
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/my_files

  # we will be testing this option being turned on all the time
  export BUILDKITE_PLUGIN_CACHE_SOFT_FAIL=true

  # necessary for key-calculations
  export BUILDKITE_LABEL="step-label"
  export BUILDKITE_BRANCH="tests"
  export BUILDKITE_ORGANIZATION_SLUG="bk-cache-test"
  export BUILDKITE_PIPELINE_SLUG="cache-pipeline"
}

teardown() {
  rm -rf tests/data
}

# ============================================================================
# PRE-COMMAND (RESTORE) TESTS
# ============================================================================

@test "Soft-fail restore: configuration errors still fail (missing path)" {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=step
  unset BUILDKITE_PLUGIN_CACHE_PATH

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial 'Missing path option'
}

@test "Soft-fail restore: configuration errors still fail (invalid level)" {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=unreal

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial 'Invalid cache level'
}

@test "Soft-fail restore: configuration errors still fail (file level without manifest)" {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=file
  unset BUILDKITE_PLUGIN_CACHE_MANIFEST

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial 'Missing manifest option'
}

@test "Soft-fail restore: successful restore works normally" {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=step
  unset BUILDKITE_PLUGIN_CACHE_MANIFEST

  stub cache_dummy \
    'exists \* : exit 0' \
    'get \* \* : echo "restoring cache"; exit 0'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at step level'
  refute_output --partial 'soft-fail'

  unstub cache_dummy
}

# ============================================================================
# POST-COMMAND (SAVE) TESTS
# ============================================================================

@test "Soft-fail save: missing cache path exits 0 with warning" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=step
  export BUILDKITE_PLUGIN_CACHE_FORCE=true
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/nonexistent_path

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Cache path'
  assert_output --partial 'does not exist'
  assert_output --partial 'Cache save operation failed, continuing build (soft-fail enabled)'
}

@test "Soft-fail save: backend save failure exits 0 with warning" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=step
  export BUILDKITE_PLUGIN_CACHE_FORCE=true

  stub cache_dummy \
    'save \* \* : exit 1'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Cache save operation failed, continuing build (soft-fail enabled)'

  unstub cache_dummy
}

@test "Soft-fail save: configuration errors still fail (missing path)" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=step
  unset BUILDKITE_PLUGIN_CACHE_PATH

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial 'Missing path option'
}

@test "Soft-fail save: configuration errors still fail (invalid level)" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=unreal

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial 'Invalid levels in the save list'
}

@test "Soft-fail save: configuration errors still fail (file level without manifest)" {
  export BUILDKITE_PLUGIN_CACHE_SAVE=file

  run "$PWD/hooks/post-command"

  assert_failure
  assert_output --partial 'Missing manifest option'
}

@test "Soft-fail save: multiple levels with failure exits 0 with warning" {
  export BUILDKITE_PLUGIN_CACHE_SAVE_0=branch
  export BUILDKITE_PLUGIN_CACHE_SAVE_1=step
  export BUILDKITE_PLUGIN_CACHE_FORCE=true

  stub cache_dummy \
    'save \* \* : exit 1'

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial 'Cache save operation failed, continuing build (soft-fail enabled)'

  unstub cache_dummy
}
