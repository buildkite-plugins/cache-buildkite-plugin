#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

export BUILDKITE_AGENT_CACHE_PATH="${TMPDIR:-/tmp}/cache-plugin-tests/$$"

setup() {
  rm -rf tests/data
  mkdir -p tests/data
}

teardown() {
  rm -rf tests/data
  rm -rf "${BUILDKITE_AGENT_CACHE_PATH}"
}

@test "Load cache based on a file manifest" {
  export BUILDKITE_ORGANIZATION_SLUG="buildkite"
  export BUILDKITE_PIPELINE_SLUG="agent"
  export BUILDKITE_PLUGIN_CACHE_PATHS_0_PATH="tests/data/my_files"
  export BUILDKITE_PLUGIN_CACHE_PATHS_0_MANIFEST="tests/data/my_files.lock"
  export BUILDKITE_PLUGIN_CACHE_PATHS_0_SCOPES_0="manifest"

  # write out a pre-existing manifest cache
  my_files_cached="${BUILDKITE_AGENT_CACHE_PATH}/manifest/1d7861b510532800513bbc79056b8fae22e77c36"
  mkdir -p "${my_files_cached}"
  echo "all the llamas" > "${my_files_cached}/llamas.txt"

  # write out a local manifest
  mkdir -p tests/data
  echo "manifesty things" > tests/data/my_files.lock

  run "$PWD/hooks/post-checkout"

  assert_success
  assert_output --partial "Restoring cache from"

  assert [ -e 'tests/data/my_files/llamas.txt' ]
}
