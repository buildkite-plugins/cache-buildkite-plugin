# Cache Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to store ephemeral cache files between builds.

Often builds involve fetching and and processing large amounts of data that don't change much between builds, for instance downloading npm/gem/pip/cocoapod packages from central registries, or shared compile cache for things like ccache, or large virtual machine images that can be re-used.

Buildkite recommends using [Artifacts](https://buildkite.com/docs/builds/artifacts) for build artifacts that are the result of a build and useful for humans, where as we see cache as being an optional byproduct of builds that doesn't need to be content addressable.

## Example: Persisting node_modules between builds

The most basic example is persisting node_modules between builds, either by a hash of the yarn.lock file or  shared at a pipeline and a branch level.

The `install` command is a command that is run after the cache is loaded.

```yaml
steps:
  - plugins:
      "cache:v1.0.0":
        - path: node_modules
          keys:
            - "node-modules-{{ checksum 'yarn.lock' }}"
            - "node-modules-${BUILDKITE_ORGANIZATION_SLUG}-${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BRANCH}
            - "node-modules-${BUILDKITE_ORGANIZATION_SLUG}-${BUILDKITE_PIPELINE_SLUG}"
          install: >
            yarn install
```

## Functions

The keys can contain functions in the form of `{{ function args... }}`. The following are available:

### checksum <filename>

Returns a checksum for a given file, or if a directory a checksum of all the files inside.

## Options

### `path`

The relative path to code in a checkout to cache. This will be where the cached data is written to and where it is restored to.

### `keys`

A list of keys that are created in the cache system, in order of most specific and relevant.

### `install`

A command that is run after cache has been restored, to ensure that the contents are fresh and relevant to your code.

Example: `yarn install`

## License

MIT (see [LICENSE](LICENSE))
