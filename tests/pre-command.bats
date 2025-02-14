#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export CACHE_DUMMY_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"
  echo "no alpacas" > "tests/data/my_files/alpacas.txt"

  export BUILDKITE_PLUGIN_CACHE_BACKEND=dummy
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/my_files
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=tests/data/my_files/llamas.txt

  # necessary for key-calculations
  export BUILDKITE_LABEL="step-label"
  export BUILDKITE_BRANCH="tests"
  export BUILDKITE_ORGANIZATION_SLUG="bk-cache-test"
  export BUILDKITE_PIPELINE_SLUG="cache-pipeline"
}

teardown() {
  rm -rf tests/data
}

@test 'If not setup for restoring, do nothing' {
  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache not setup for restoring'
}

@test "Missing path fails" {
  unset BUILDKITE_PLUGIN_CACHE_PATH

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial 'Missing path option'
}

@test "Invalid level fails" {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=unreal

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial 'Invalid cache level'
}

@test 'File-based cache with no manifest fails' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=file
  unset BUILDKITE_PLUGIN_CACHE_MANIFEST

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial 'Missing manifest option'
}

@test 'Non-existing file-based restore does nothing' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=file

  stub cache_dummy \
    'exists \* : exit 1'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache miss up to file-level, sorry'

  unstub cache_dummy
}

@test 'Non-existing step-based restore does nothing' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=step

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache miss up to step-level, sorry'

  unstub cache_dummy
}

@test 'Non-file level restore without manifest does not check file-level' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=step
  unset BUILDKITE_PLUGIN_CACHE_MANIFEST

  stub cache_dummy \
    'exists \* : exit 1'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache miss up to step-level, sorry'

  unstub cache_dummy
}

@test 'Non-existing branch-based restore does nothing' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=branch

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache miss up to branch-level, sorry'

  unstub cache_dummy
}
@test 'Non-existing pipeline-based restore does nothing' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=pipeline

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache miss up to pipeline-level, sorry'

  unstub cache_dummy
}

@test 'Non-existing all-based restore does nothing' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=all

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1'

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache miss up to all-level, sorry'

  unstub cache_dummy
}

@test 'Existing file-based restore' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=file

  stub cache_dummy \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at file level'

  unstub cache_dummy
}

@test 'Existing file-based restore even when max-level is higher' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=all

  stub cache_dummy \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at file level'

  unstub cache_dummy
}

@test 'Existing step-based restore' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=step

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at step level'

  unstub cache_dummy
}

@test 'Existing branch-based restore' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=branch

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at branch level'

  unstub cache_dummy
}
@test 'Existing pipeline-based restore' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=pipeline

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at pipeline level'

  unstub cache_dummy
}

@test 'Existing all-based restore' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=all

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at all level'

  unstub cache_dummy
}

@test 'Existing lower level restore works' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=all

  stub cache_dummy \
    'exists \* : exit 1' \
    'exists \* : exit 1' \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at branch level'

  unstub cache_dummy
}
