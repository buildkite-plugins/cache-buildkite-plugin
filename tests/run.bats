#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

@test "Cache some files" {
  run $PWD/hooks/post-checkout

  assert_success
}
