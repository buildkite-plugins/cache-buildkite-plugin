# Cache Buildkite Plugin [![Build status](https://badge.buildkite.com/6e29c2a268dddb82724ba1bfb3abd484d8595631849f8dbc31.svg?branch=master)](https://buildkite.com/buildkite/plugins-cache)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to store ephemeral cache files between builds.

Often builds involve fetching and processing large amounts of data that don't change much between builds, for instance downloading npm/gem/pip/cocoapod packages from central registries, or shared compile cache for things like ccache, or large virtual machine images that can be re-used.

Buildkite recommends using [Artifacts](https://buildkite.com/docs/builds/artifacts) for build artifacts that are the result of a build and useful for humans, where as we see cache as being an optional byproduct of builds that doesn't need to be content addressable.

For example, caching the `node_modules` folder as long as the `package-lock.json` file does not change can be done as follows:

```yaml
steps:
  - label: ':nodejs: Install dependencies'
    command: npm ci
    plugins:
      - cache#v1.5.2:
          manifest: package-lock.json
          path: node_modules
          restore: file
          save: file
```

## Mandatory parameters

### `path` (string)

The file or folder to cache.

### At least one of the following

#### `restore` (string, specific values)

The maximum caching level to restore, if available. See [the available caching levels](#caching-levels)

#### `save` (string or array of strings, specific values)

The level(s) to use for saving the cache. See [the available caching levels](#caching-levels).

You can specify multiple levels in an array to save the same artifact as a cache for all those levels.

## Options

### `backend` (string)

Defines how the cache is stored and restored. Can be any string (see [Customizable Backends](#customizable-backends)), but the plugin natively supports the following:
* `fs` (default)
* `s3`

#### `fs`

Very basic local filesystem backend.

The `BUILDKITE_PLUGIN_FS_CACHE_FOLDER` environment variable defines where the copies are  (default: `/var/cache/buildkite`). If you don't change it, you will need to make sure that the folder exists and `buildkite-agent` has the propper permissions, otherwise the plugin will fail.

**IMPORTANT**: the `fs` backend just copies files to a different location in the current agent, as it is not a shared or external resource, its caching possibilities are quite limited.

#### `s3`

Store things in an S3 bucket. You need to make sure that the `aws` command is available and appropriately configured.

You also need the agent to have access to the following defined environment variables:
* `BUILDKITE_PLUGIN_S3_CACHE_BUCKET`: the bucket to use (backend will fail if not defined)
* `BUILDKITE_PLUGIN_S3_CACHE_PREFIX`: optional prefix to use for the cache within the bucket
* `BUILDKITE_PLUGIN_S3_CACHE_ENDPOINT`: optional S3 custom endpoint to use

Setting the `BUILDKITE_PLUGIN_S3_CACHE_ONLY_SHOW_ERRORS` environment variable will reduce logging of file operations towards S3.

### `compression` (string)

Allows for the cached file/folder to be saved/restored as a single file. You will need to make sure to use the same compression when saving and restoring or it will cause a cache miss.

The value `none` is equivalent to not specifying a compression. Any other value (`X`) will assume that an executable wrapper script exists in the agent's `PATH` to handle both compression and decompression with the following protocol:
* `X_wrapper compress SOURCE TARGET`: compress the file/folder `SOURCE` into the `TARGET` file
* `X_wrapper decompress SOURCE TARGET`: decompress the artifact `SOURCE` into `TARGET` destination

The plugin includes wrappers to provide both examples and backwards-compatibility:
* `tgz`: `tar` with gzip compression
* `zip`: `(un)zip` compression
* `zstd`: `zstd` compression

### `force` (boolean, save only)

Force saving the cache even if it exists. Default: `false`.

### `keep-compressed-artifacts` (boolean)

Remove compression artifacts after they are used. Default: `false`.

Note that if you turn on this option, every execution will create temporary files that may fill up your agent's storage.

### `manifest` (string or list of strings, required if using `file` caching level)

One or more paths to files or folders that will be hashed to create and restore file-level caches. If multiple files or folders are specified its ordering does not matter.

It will cause an unrecoverable error if either `save` or `restore` are set to `file` and this option is not specified.

## Caching levels

This plugin uses the following hierarchical structure for caches to be valid (meaning usable), from the most specific to the more general:
* `file`: only as long as the contents of the files or folders of the `manifest` option do not change
* `step`: valid only for the current step
* `branch`: when the pipeline executes in the context of the current branch
* `pipeline`: all builds and steps of the pipeline
* `all`: all the time

When restoring from cache, **all levels, in the described order, up to the one specified** will be checked. The first one available will be restored and no further levels or checks will be made.

## Customizable backends

One of the greatest flexibilities of this plugin is its flexible backend architecture. You can provide whatever value you want for the `backend` option of this plugin (`X` for example) as long as there is an executable script accessible to the agent named `cache_X` that respects the following execution protocol:

* `cache_X exists $KEY`

Should exit successfully (0 return code) if any previous call to this very same plugin was made with `cache_x save $KEY`. Any other exit code will mean that there is no valid cache and will be ignored.

* `cache_X get $KEY $FILENAME`

Will restore whatever was previously saved on `$KEY` (using the `save` call described next) to the file or folder `$FILENAME`. A non-0 exit code will cause the whole execution to halth and the current step to fail.

You can assume that all calls like this will be preceded by an `exists` call to ensure that there is something to get.

* `cache_X save $KEY $FILENAME`

Will save whatever is in the `$FILENAME` path (which can be a file or folder) in a way that can be identified by the string `$KEY`. A non-0 return code will cause the whole execution to halt and the current step to fail.

* should fail with error 255 on any instance, preferably without output

## Examples

You can always have more complicated logic by using the plugin multiple times with different levels and on different steps. In the following example the `node_modules` folder will be saved and restored with the following logic:

* first step:
  - if the `package-lock.json` file has not changed, `node_modules` will be restored as is, run the `npm install` (that should do nothing because no dependencies changed), and skip saving the cache because it already exists
  - if the `package-lock.json` file has changed, it will restore step-level, branch-level and pipeline-level caches of the `node_modules` folder (the first one that exists), run `npm install` (that should be quick, just installing the differences), and then save the resulting `node_modules` folder as a file-level cache
* second step:
  - will restore the file-level cache of the `node_modules` folder saved by the first step and run `npm test`
* third step (that will only run on the `master` branch):
  - will restore the file-level cache saved by the first step, run `npm run deploy` and finally save the contents of the `node_modules` folder as both a pipeline-level and global (all-level) cache for usage as a basis even when the lockfile changes (in the first step)

```yaml
steps:
  - label: ':nodejs: Install dependencies'
    command: npm ci
    plugins:
      - cache#v1.5.2:
          manifest: package-lock.json
          path: node_modules
          restore: pipeline
          save:
            - file
            - branch
  - wait: ~
  - label: ':test_tube: Run tests'
    command: npm test # does not save cache, not necessary
    plugins:
      - cache#v1.5.2:
          manifest: package-lock.json
          path: node_modules
          restore: file
  - wait: ~  # don't run deploy until tests pass
  - label: ':goal_net: Save stable cache after deployment'
    if: build.branch == "master"
    command: npm run deploy
    plugins:
      - cache#v1.5.2:
          manifest: package-lock.json
          path: node_modules
          restore: file
          save:
            - pipeline
            - all

```

## License

MIT (see [LICENSE](LICENSE))
