# paramsync

Paramsync is a simple, straightforward CLI tool for synchronizing data from the
filesystem to the Consul KV store and vice-versa.

## Basic Usage

Run `paramsync check` to see what differences exist, and `paramsync push` to
synchronize the changes from the filesystem to Consul.

    $ paramsync check
    =====================================================================================
    myapp-private
    local:consul/private => consul:dc1:private/myapp
      Keys scanned: 37
    No changes to make for this sync target.

    =====================================================================================
    myapp-config
    local:consul/config => consul:dc1:config/myapp
      Keys scanned: 80

    UPDATE config/myapp/prod/ip-allowlist.json
    -------------------------------------------------------------------------------------
    -["10.8.0.0/16"]
    +["10.8.0.0/16","10.9.10.0/24"]
    -------------------------------------------------------------------------------------

    Keys to update: 1
    ~ config/myapp/prod/ip-allowlist.json

You can also limit your command to specific synchronization targets by using
the `--target` flag:

    $ paramsync push --target myapp-config
    =====================================================================================
    myapp-config
    local:consul/config => consul:dc1:config/myapp
      Keys scanned: 80

    UPDATE config/myapp/prod/ip-allowlist.json
    -------------------------------------------------------------------------------------
    -["10.8.0.0/16"]
    +["10.8.0.0/16","10.9.10.0/24"]
    -------------------------------------------------------------------------------------

    Keys to update: 1
    ~ config/myapp/prod/ip-allowlist.json

    Do you want to push these changes?
      Enter 'yes' to continue: yes

    UPDATE config/myapp/prod/ip-allowlist.json   OK

Run `paramsync --help` for additional options and commands.

## Pull Mode

Paramsync can also sync _from_ Consul to the local filesystem. This can be
particularly useful for seeding a git repo with the current contents of a Consul
KV database.

Run `paramsync check --pull` to get a summary of changes, and `paramsync pull`
to actually sync the changes to the local filesystem. Additional arguments such
as `--target <name>` work in pull mode as well.


## Configuration

Paramsync will automatically configure itself using the first `paramsync.yml`
file it comes across when searching backwards through the directory tree from
the current working directory. So, typically you may wish to place the config
file in the root of your git repository or the base directory of your config
file tree.

You can also specify a config file using the `--config <filename>` command line
argument.


### Configuration file structure

The configuration file is a Hash represented in YAML format with three possible
top-level keys: `paramsync`, `consul`, and `sync`. The `paramsync` section sets
global defaults and app options. The `consul` section specifies the URL to the
Consul REST API endpoint. And the `sync` section lists the directories and
Consul prefixes you wish to synchronize. Only the `sync` section is strictly
required. An example `paramsync.yml` is below including explanatory comments:

    # paramsync.yml

    paramsync:
      # verbose - defaults to `false`
      #   Set this to `true` for more verbose output.
      verbose: false

      # chomp - defaults to `true`
      #   Automatically runs `chomp` on the strings read in from files to
      #   eliminate a single trailing newline character (commonly inserted
      #   by text editors). Set to `false` to disable this by default for
      #   all sync targets (it can be overridden on a per-target basis).
      chomp: true

      # delete - defaults to `false`
      #   Set this to `true` to make the default for all sync targets to
      #   delete any keys found in Consul that do not have a corresponding
      #   file on disk. By default, extraneous remote keys will be ignored.
      #   If `verbose` is set to `true` the extraneous keys will be named
      #   in the output.
      delete: false

      # color - defaults to `true`
      #   Set this to `false` to disable colorized output (eg when running
      #   with an automated tool).
      color: true

    consul:
      # url - defaults to `http://localhost:8500`
      #   The REST API endpoint for the Consul agent.
      url: http://localhost:8500

      # datacenter - defaults to nil
      #   Set this to change the default datacenter for sync targets to
      #   something other than the datacenter of the Consul agent.
      datacenter: dc1

      # token_source - defaults to 'none'
      #   'none': expect no Consul token (although env vars will be used if they are set)
      #   'env': expect Consul token to be set in CONSUL_TOKEN or CONSUL_HTTP_TOKEN
      #   'vault': read Consul token from Vault based on settings in the 'vault' section
      #   'vault.<label>': a named Vault token source, eg `vault.us-east-1` or `vault.dev`
      #      NOTE: labels must begin with a letter and may contain only (ASCII) letters,
      #            numbers, hyphens, and underscores

    # the vault section is only necessary if consul.token_source is set to 'vault'
    vault:
      # url - defaults to the value of VAULT_ADDR
      #   The REST API endpoint of your Vault server
      url: https://your.vault.example

      # consul_token_path - the path to the endpoint from which to read the Consul token
      #   The Vault URI path to the Consul token - can be either the Consul
      #   dynamic backend or a KV endpoint with a static value. If the dynamic
      #   backend is used, the lease will be automatically revoked when
      #   paramsync exits.
      consul_token_path: consul/creds/my-role

      # consul_token_field - name of the field in which the Consul token is stored
      #   Defaults to 'token' which is the field used by the dynamic backend
      #   but can be set to something else for static values.
      consul_token_field: token

    # You can define one or more 'vault.<label>' sections to define alternative Vault
    # token sources for use in individual sync targets.
    vault.other:
      url: https://your.vault.example
      consul_token_path: consul/creds/my-other-role
    vault.dev:
      url: https://dev.vault.example
      consul_token_path: consul/creds/my-dev-role

    sync:
      # sync is an array of hashes of sync target configurations
      #   Fields:
      #     name - The arbitrary friendly name of the sync target. Only
      #       required if you wish to target specific sync targets using
      #       the `--target` CLI flag.
      #     prefix - (required) The Consul KV prefix to synchronize to.
      #     type - (default: "dir") The type of local file storage. Either
      #       'dir' to indicate a directory tree of files corresponding to
      #       Consul keys; or 'file' to indicate a single YAML file with a
      #       map of relative key paths to values.
      #     datacenter - The Consul datacenter to synchronize to. If not
      #       specified, the `datacenter` setting in the `consul` section
      #       will be used. If that is also not specified, the sync will
      #       happen with the local datacenter of the Consul agent.
      #     path - (required) The relative filesystem path to either the
      #       directory containing the files with content to synchronize
      #       to Consul if this sync target has type=dir, or the local file
      #       containing a hash of remote keys if this sync target has
      #       type=file. This path is calculated relative to the directory
      #       containing the configuration file.
      #     token_source - An alternative token source other than the
      #       default. Potential values are the same as for the
      #       consul.token_source config value: 'none', 'env', 'vault',
      #       or 'vault.<label>'.
      #     delete - Whether or not to delete remote keys that do not exist
      #       in the local filesystem. This inherits the setting from the
      #       `paramsync` section, or if not specified, defaults to `false`.
      #     chomp - Whether or not to chomp a single newline character off
      #       the contents of local files before synchronizing to Consul.
      #       This inherits the setting from the `paramsync` section, or if
      #       not specified, defaults to `true`.
      #     exclude - An array of Consul KV paths to exclude from the
      #       sync process. These exclusions will be noted in output if the
      #       verbose mode is in effect, otherwise they will be silently
      #       ignored. At this time there is no provision for specifying
      #       prefixes or patterns. Each key must be fully and explicitly
      #       specified.
      #     erb_enabled - Whether or not to run the local content through
      #       ERB parsing before attempting to sync to the remote. Defaults
      #       to `false`.
      - name: myapp-config
        prefix: config/myapp
        datacenter: dc1
        path: consul/config
        exclude:
          - config/myapp/beta/cowboy-yolo
          - config/myapp/prod/cowboy-yolo
      - name: myapp-private
        prefix: private/myapp
        type: dir
        datacenter: dc1
        path: consul/private
        token_source: vault.dev
        delete: true
      - name: yourapp-config
        prefix: config/yourapp
        type: file
        datacenter: dc1
        path: consul/yourapp.yml
        delete: true
        erb_enabled: true

You can run `paramsync config` to get a summary of the defined configuration
and to double-check config syntax.

### File sync targets

When using `type: file` for a sync target (see example above), the local path
should be a YAML (or JSON) file containing a hash of relative key paths to the
contents of those keys. So for example, given this configuration:

    sync:
      - name: config
        prefix: config/yourapp
        type: file
        datacenter: dc1
        path: yourapp.yml

If the file `yourapp.yml` has the following content:

    ---
    prod/dbname: yourapp
    prod/message: |
      Hello, world. This is a multiline message.
      Thanks.
    prod/app/config.json: |
      {
        "port": 8080,
        "enabled": true
      }

Then `paramsync push` will attempt to create and/or update the following keys
with the corresponding content from `yourapp.yml`:

| Key  | Value  |
|:-----|:-------|
| `config/yourapp/prod/dbname` | `yourapp` |
| `config/yourapp/prod/message` | `Hello, world. This is a multiline message.\nThanks.` |
| `config/yourapp/prod/app/config.json` | `{\n  "port": 8080,\n  "enabled": true\n}` |

In addition to specifying the entire relative path in each key, you may also
reference paths via your file's YAML structure directly. For example:

    ---
    prod:
      redis:
        port: 6380
        host: redis.example.com

When pushed, this document will create and/or update the following keys:

| Key  | Value  |
|:-----|:-------|
| `config/yourapp/prod/redis/port` | `6380` |
| `config/yourapp/prod/redis/host` | `redis.example.com` |

You may mix and match relative paths and document hierarchy to build paths as
you would like. And you may also use the special key `_` to embed a value for
a particular prefix while also nesting values underneath it. For example, given
this local file target content:

    ---
    prod/postgres:
      host: db.myproject.example.com
      port: 10001

    prod:
      redis:
        _: Embedded Value
        port: 6380

    prod/redis/host: cache.myproject.example.com

This file target content would correspond to the following values, when pushed:

| Key  | Value  |
|:-----|:-------|
| `config/yourapp/prod/postgres/host` | `db.myproject.example.com` |
| `config/yourapp/prod/postgres/port` | `10001` |
| `config/yourapp/prod/redis` | `Embedded Value` |
| `config/yourapp/prod/redis/port` | `6380` |
| `config/yourapp/prod/redis/host` | `cache.myproject.example.com` |

A `paramsync pull` operation against a file type target will work in reverse,
and pull values from any keys under `config/yourapp/` into the file
`yourapp.yml`, overwriting whatever values are there.

**NOTE**: Values in local file targets are converted to strings before comparing
with or uploading to the remote Consul server. However, because YAML parsing
converts some values (such as `yes` or `no`) to boolean types, the effective
value of a key with a value of a bare `yes` will be `true` when converted to a
string. If you need the actual values `yes` or `no`, use quotes around the value
to force the YAML parser to interpret it as a string.


#### IMPORTANT NOTES ABOUT PULL MODE WITH FILE TARGETS

Against a file target, the structure of the local file can vary in a number
of ways while still producing the same remote structure. Thus, in pull mode,
Paramsync must necessarily choose one particular rendering format, and will not
be able to retain the exact structure of the local file if you alternate push
and pull operations.

Specifically, the following caveats are important to note, when pulling a target
to a local file:

* The local file will be written out as YAML, even if it was originally
  provided locally as a JSON file, and even if the extension is `.json`.

* Any existing comments in the local file will be lost.

* The document structure will be that of a flat hash will fully-specified
  relative paths as the keys.

Future versions of Paramsync may provide options to modify the behavior for pull
operations on a per-target basis. Pull requests are always welcome.


### Dynamic configuration

The configuration file will be rendered through ERB before being parsed as
YAML. This can be useful for avoiding repetitive configuration across multiple
prefixes or datacenters, eg:

    sync:
    <% %w( dc1 dc2 dc3 ).each do |dc| %>
      - name: <%= dc %>:myapp-private
        prefix: private/myapp
        datacenter: <%= dc %>
        path: consul/<%= dc %>/private
        delete: true
    <% end %>

It's a good idea to sanity-check your ERB by running `paramsync config` after
making any changes.


### Dynamic content

You can also choose to enable ERB parsing for local content as well, by setting
`erb_enabled: true` on any sync targets you wish to populate in this way.


### Environment configuration

Paramsync may be partially configured using environment variables:
* `PARAMSYNC_VERBOSE` - set this variable to any value to enable verbose mode
* `CONSUL_HTTP_TOKEN` or `CONSUL_TOKEN` - use one of these variables (priority
  is given to `CONSUL_HTTP_TOKEN`) to set an explicit Consul token to use when
  interacting with the API. Otherwise, by default the agent's `acl_token`
  setting is used implicitly.
* `VAULT_ADDR` and `VAULT_TOKEN` - if `consul.token_source` is set to `vault`
  or `vault.<label>`, these variables are used to authenticate to Vault. If
  `VAULT_TOKEN` is not set, Paramsync will attempt to read a token from
  `~/.vault-token`. If the `url` field is set, it will take priority over the
  `VAULT_ADDR` environment variable, but one or the other must be set.


## Roadmap

Paramsync is relatively new software. There's more to be done. Some ideas, which
may or may not ever be implemented:

* Using CAS to verify the key has not changed in the interim before updating/deleting
* Options for file target pull-mode rendering
* Automation support for running non-interactively
* Pattern- and prefix-based exclusions
* Logging of changes to files, syslog, other services
* Other commands to assist in managing Consul KV sets
* Git awareness (branches, commit state, etc)
* Automated tests
* Submitting changes in batches using transactions


## Contributing

I'm happy to accept suggestions, bug reports, and pull requests through Github.


## License

This software is public domain. No rights are reserved. See LICENSE for more
information.
