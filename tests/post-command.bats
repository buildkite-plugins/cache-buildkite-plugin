#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

export BUILDKITE_AGENT_CACHE_PATH="${TMPDIR:-/tmp}/cache-plugin-tests/$$"

setup() {
  rm -rf tests/data
  mkdir -p tests/data
}

teardown() {
  rm -rf tests/data
  rm -rf "${BUILDKITE_AGENT_CACHE_PATH}"
}

@test "Save cache based on a file manifest" {
  export BUILDKITE_ORGANIZATION_SLUG="buildkite"
  export BUILDKITE_PIPELINE_SLUG="agent"
  export BUILDKITE_PLUGIN_CACHE_DEBUG=true
  export BUILDKITE_PLUGIN_CACHE_0_PATH="tests/data/my_files"
  export BUILDKITE_PLUGIN_CACHE_0_MANIFEST="tests/data/my_files.lock"
  export BUILDKITE_PLUGIN_CACHE_0_SCOPES_0="manifest"

  # write out some local files
  mkdir -p tests/data/my_files
  echo "all the llamas" > "tests/data/my_files/llamas.txt"

  # write out a local manifest
  mkdir -p tests/data
  echo "manifesty things" > tests/data/my_files.lock

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Caching tests/data/my_files to"

  expected_cache_file="${BUILDKITE_AGENT_CACHE_PATH}/manifest/1d7861b510532800513bbc79056b8fae22e77c36"
  assert [ -e "$expected_cache_file" ]
}
