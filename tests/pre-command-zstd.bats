#!/usr/bin/env bats

# To debug stubs, uncomment these lines:
# export CACHE_DUMMY_STUB_DEBUG=/dev/tty
# export TAR_STUB_DEBUG=/dev/tty

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"
  echo "no alpacas" > "tests/data/my_files/alpacas.txt"

  export BUILDKITE_PLUGIN_CACHE_BACKEND=dummy
  export BUILDKITE_PLUGIN_CACHE_COMPRESSION=zstd
  export BUILDKITE_PLUGIN_CACHE_PATH=tests/data/my_files
  export BUILDKITE_PLUGIN_CACHE_MANIFEST=tests/data/my_files/llamas.txt

  # necessary for key-calculations
  export BUILDKITE_LABEL="step-label"
  export BUILDKITE_BRANCH="tests"
  export BUILDKITE_ORGANIZATION_SLUG="bk-cache-test"
  export BUILDKITE_PIPELINE_SLUG="cache-pipeline"

  stub tar \
    "--help : echo '--zstd'" \
    "echo called tar with options \$@"
}

teardown() {
  rm -rf tests/data

  unstub tar
}

@test 'Existing file-based restore' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=file

  stub cache_dummy \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at file level'
  assert_output --partial 'Cache is compressed, decompressing with zstd'

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
  assert_output --partial 'Cache is compressed, decompressing with zstd'

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
  assert_output --partial 'Cache is compressed, decompressing with zstd'

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
  assert_output --partial 'Cache is compressed, decompressing with zstd'

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
  assert_output --partial 'Cache is compressed, decompressing with zstd'

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
  assert_output --partial 'Cache is compressed, decompressing with zstd'

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
  assert_output --partial 'Cache is compressed, decompressing with zstd'

  unstub cache_dummy
}

@test 'Existing file-based restore to absolute path' {
  export BUILDKITE_PLUGIN_CACHE_RESTORE=file
  export BUILDKITE_PLUGIN_CACHE_PATH=/tmp/tests/data/my_files

  stub cache_dummy \
    'exists \* : exit 0' \
    "get \* \* : echo restoring \$2 to \$3"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial 'Cache hit at file level'
  assert_output --partial 'Cache is compressed, decompressing with zstd...'

  unstub cache_dummy
}
