# Implementation plan for 0.2.0

Scope requested on 2026-11-17: the remaining security API parts (action
groups, API keys, tenants, multi-tenancy, allow list), index operations,
aliases, ingest pipelines, stored scripts and task management.

`opensearch_action_group` already exists since 0.1.0 and needs no work.

## 1. Two kinds of features

Most of the list is **state** that Puppet can compare and converge, so it
becomes types like in 0.1.0. Index operations such as flush, force merge,
shrink or rollover, and task management (list, cancel) are **actions**. They
have no desired state: running a force merge on every Puppet run would be
wrong. They become **Puppet tasks** (`tasks/*.json` + Ruby), run with Bolt or
another task runner on an OpenSearch node. They use the same connection file
and client library as the types.

| Area | Form | Name |
|---|---|---|
| Tenants | type | `opensearch_tenant` |
| Multi-tenancy | type (one per connection) | `opensearch_tenancy_config` |
| Allow list | type (one per connection) | `opensearch_allowlist` |
| API keys | type, see decision 1 | `opensearch_api_key` |
| Indices | type | `opensearch_index` |
| Aliases | type | `opensearch_alias` |
| Ingest pipelines | type | `opensearch_ingest_pipeline` |
| Search pipelines | type, see decision 4 | `opensearch_search_pipeline` |
| Stored scripts and search templates | type | `opensearch_stored_script` |
| Index operations | tasks | `manage_opensearch::index_*` |
| Task management | tasks | `manage_opensearch::task_*` |

## 2. Types

Same conventions as 0.1.0: Resource API, titles `name` or `connection/name`,
only set attributes are managed, `puppet resource` lists all objects,
reserved/static/hidden objects are skipped.

### Security

| Type | Endpoint | Attributes | Notes |
|---|---|---|---|
| `opensearch_tenant` | `_plugins/_security/api/tenants/{name}` | `description` | like action groups; `global_tenant` is reserved |
| `opensearch_tenancy_config` | `_plugins/_security/api/tenancy/config` | `multitenancy_enabled`, `private_tenant_enabled`, `default_tenant`, `sign_in_options`, `preferred_tenants` | one object per cluster: the title is the connection name (`default`); no `ensure` |
| `opensearch_allowlist` | `_plugins/_security/api/allowlist` | `enabled`, `requests` (path => methods) | one object per cluster; **needs a connection with the admin certificate**, basic auth gets 403 |
| `opensearch_api_key` | `_plugins/_security/api/apitokens` | `cluster_permissions`, `index_permissions`, `duration`, … | OpenSearch ≥ 3.7, and `api_tokens.enabled` in the security config; see decision 1 |

API keys, as tested on 3.9.0:

* Off by default ("API tokens are not enabled"). Enabled in `config.yml`
  (`config.dynamic.api_tokens.enabled: true`), or over the REST API only if
  the node setting
  `plugins.security.unsupported.restapi.allow_securityconfig_modification`
  is set. The module does not manage the security config.
* Each key needs an expiry; at most 90 days (`max_duration_seconds`).
* The secret is returned once, on creation.
* Keys cannot be changed, only revoked (`DELETE apitokens/{id}`). Revoked
  and expired keys stay in the list. Names are unique.

### Indices and aliases

`opensearch_index`:

* `ensure` (`present`, `absent`), `state` (`open`, `closed`), `settings`,
  `mappings`.
* `settings`: normalized like index templates. Dynamic settings (replicas,
  refresh interval, …) are updated in place. Static settings (shards, codec,
  …) only apply at creation; a difference later fails the resource with a
  clear message instead of silently doing nothing.
* `mappings`: compared as a subset (fields set in the manifest must match).
  New fields are added with `PUT _mapping`. Changing the type of an existing
  field is not possible in OpenSearch and fails.
* Not listed and not purged: indices starting with `.` (system, hidden, data
  stream backing indices `.ds-*`) and indices with `index.hidden`.
* `ensure => absent` deletes the index and its data.
* Aliases are not an attribute of `opensearch_index`, only of
  `opensearch_alias`, so that there is one place for them.

`opensearch_alias`:

* Title = alias name. `indices` (concrete index names, no wildcards),
  `write_index`, `filter`, `routing`, `index_routing`, `search_routing`,
  `is_hidden`.
* Changes go through `POST _aliases` with add and remove actions in one
  request, so they are atomic.
* Don't manage an alias that ISM rolls over (`rollover_alias`): ISM moves
  the write index and Puppet would move it back. Documented.

### Pipelines and scripts

| Type | Endpoint | Attributes | Notes |
|---|---|---|---|
| `opensearch_ingest_pipeline` | `_ingest/pipeline/{id}` | `description`, `processors`, `on_failure`, `version` | exact comparison of `processors` (order matters); `_meta` is rejected by 3.9 and left out |
| `opensearch_search_pipeline` | `_search/pipeline/{id}` | `description`, `request_processors`, `response_processors`, `phase_results_processors`, `version` | see decision 4 |
| `opensearch_stored_script` | `_scripts/{id}` | `lang`, `source` (String or Hash), `context` | no list endpoint: listing reads `_cluster/state/metadata/stored_scripts`. Mustache templates come back as a JSON string, so a Hash `source` is compared parsed. `context` is only used to compile-check on PUT |

## 3. Tasks

Ruby tasks run with the agent's Ruby (`/opt/puppetlabs/puppet/bin/ruby`).
They ship `lib/puppet_x/manage_opensearch/` via `files` in the task metadata
and read the connection file, so they run as root on a node with the class.
Each takes an optional `connection` parameter (default `default`) and
returns the API response as JSON. Long operations take
`wait_for_completion` and, if it is false, return a task ID for the task
management tasks.

Index operations (one task each, so that each has its own parameters):

| Task | API |
|---|---|
| `index_open`, `index_close` | `_open`, `_close` |
| `index_refresh`, `index_flush` | `_refresh`, `_flush` |
| `index_clear_cache` | `_cache/clear` |
| `index_forcemerge` | `_forcemerge` (`max_num_segments`, `only_expunge_deletes`) |
| `index_clone`, `index_shrink`, `index_split` | `_clone`, `_shrink`, `_split` (target, settings) |
| `index_rollover` | `_rollover` (alias or data stream, conditions, dry run) |
| `index_scale` | `_scale` (`search_only`; OpenSearch 3 only) |
| `index_stats`, `index_recovery`, `index_segments`, `index_shard_stores` | read-only reports |

Clone and shrink need the source to be read-only first; the tasks don't do
that themselves but say so in the error.

Task management:

| Task | API |
|---|---|
| `task_list` | `GET _tasks` (`actions`, `nodes`, `parent_task_id`, `detailed`) |
| `task_get` | `GET _tasks/{id}` (`wait_for_completion`, `timeout`) |
| `task_cancel` | `POST _tasks/{id}/_cancel` or `_tasks/_cancel?actions=…` |
| `task_rethrottle` | `POST _{reindex,update_by_query,delete_by_query}/{id}/_rethrottle` |

## 4. Tests

* Unit tests for every provider and task, like 0.1.0.
* Integration: manifests 90+ for the new types, each applied twice. Tasks
  are run directly in the agent container with JSON on stdin (no Bolt
  needed). The allow list test uses the demo admin certificate (`kirk.pem`)
  copied from the OpenSearch container. API keys are tested only on 3.9 (the
  CI already has a 2.19 job; there the type must fail with a clear message),
  with `api_tokens` enabled through the container's security config.
* CI matrix unchanged: OpenSearch 2.19.7 and 3.9.0 × OpenVox 8 and 9.

## 5. Milestones

1. Security: tenant, tenancy config, allow list (with a singleton variant of
   the provider base class). *(done)*
2. Ingest pipelines, search pipelines, stored scripts. *(done)*
3. Aliases, then indices. *(done)*
4. Task infrastructure (shared helper, metadata, test runner), then the
   index operation and task management tasks. *(deferred, decision 2)*
5. API keys. *(deferred, decision 1)*
6. README, EXAMPLES, REFERENCE, CHANGELOG; tag `v0.2.0` locally. *(done)*

## 6. Decisions (2026-11-17)

1. **API keys**: left out for now.
2. **Tasks** (index operations and task management): left out for now.
   Opening and closing an index is covered by `opensearch_index` (`state`).
3. **`opensearch_index`**: needed. Templates and data streams are the
   preferred way, but single indices must be possible.
4. **Search pipelines**: included.

Scope of 0.2.0 therefore: `opensearch_tenant`, `opensearch_tenancy_config`,
`opensearch_allowlist`, `opensearch_ingest_pipeline`,
`opensearch_search_pipeline`, `opensearch_stored_script`, `opensearch_alias`,
`opensearch_index`. Section 3 and milestones 4 and 5 are deferred.
