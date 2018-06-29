# Cache Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to store ephemeral cache files between builds.

Often builds involve fetching and and processing large amounts of data that don't change much between builds, for instance downloading npm/gem/pip/cocoapod packages from central registries, or shared compile cache for things like ccache, or large virtual machine images that can be re-used.

Buildkite recommends using [Artifacts](https://buildkite.com/docs/builds/artifacts) for build artifacts that are the result of a build and useful for humans, where as we see cache as being an optional byproduct of builds that doesn't need to be content addressable.

## Status

This is largely still imaginary 🦑.

* [ ] Basic caching based on a single file manifest
* [ ] Multiple manifest files
* [ ] Directories as manifests
* [ ] Command Execution on cache miss
* [ ] Scopes:
  * [ ] manifest
  * [ ] branch
  * [ ] pipeline
  * [ ] org
* [ ] Hooks
  * [ ] post-restore
  * [ ] post-save
  * [ ] post-cache-miss

## Example: Persisting node_modules between builds

The most basic example is persisting node_modules between builds, either by a hash of the yarn.lock file or  shared at a branch level and a pipeline level.

```yaml
steps:
  - command: yarn install
    plugins: &plugins
      "cache:v1.0.0":
        - path: node_modules
          manifest: yarn.lock
          scopes:
            - manifest
            - branch
            - pipeline

  - wait
  - command: yarn lint
    plugins: *plugins

  - wait
  - command: yarn test
    plugins: *plugins
```

## Example: Only doing packer builds when files have changed

This is an example of using the cache to skip commands if they don't need to be executed. The `post-cache-miss` command is only executed if there is a cache miss. This can be used for de-duplicating builds of things like packer or AMI's.

See https://github.com/buildkite/elastic-ci-stack-for-aws/blob/2ce67b7e0875ed47f1e296265881764f8ec4eca9/.buildkite/steps/packer.sh for how we currently do this manually.

```yaml
steps:
  - plugins:
      "cache:v1.0.0":
        - path: packer_result.yml
          manifest:
             - packer/
             - plugins/
          scopes:
            - manifest
          post-cache-miss:
            - ./build_packer_image
```

## Storage

Initially cache is stored on the agent filesystem. Different agents on the same host will share a cache, but it's still host-bound.

Agents need to opt-in to this storage by setting `BUILDKITE_AGENT_CACHE_PATH` in their env, otherwise the plugin will fail.

Pretty quickly we will add support for storing this cache on AWS S3, Google Cloud and ilk.

## Options

### `path`

The relative path to code in a checkout to cache. This will be where the cached data is written to and where it is restored to.

### `manifest`

A file to hash that represents the contents of the `path`.

Example: `Gemfile.lock`, `yarn.lock`

### `scopes`

The scopes that the cached path will be saved into and restored from, in order of specificity. Possible options are:

  * `manifest` is an exact match on the hash of the files listed in the `manifest` directive.
  * `branch` is a match on the org slug, pipeline slug and the git branch name
  * `pipeline` is a match on the org slug and pipeline slug
  * `org` is a match on the org slug

Keep in mind that the more scopes you specify, the slower save and restore operations will be.

### `post-restore`

Commands to be run after the cache is restored.

Example: `yarn install`

## License

MIT (see [LICENSE](LICENSE))
