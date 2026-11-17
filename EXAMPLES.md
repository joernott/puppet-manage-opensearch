# Examples

## User and role management

A user `metrics` for Java applications that write to the `metrics*` indices.
A role grants the write access, and a role mapping gives the role to the user.

```puppet
opensearch_role { 'metrics_writer':
  description         => 'Write access to the metrics* indices',
  cluster_permissions => ['indices:data/write/bulk'],
  index_permissions   => [
    {
      index_patterns  => ['metrics*'],
      allowed_actions => ['write', 'create_index', 'indices:admin/mapping/put'],
    },
  ],
}

opensearch_internal_user { 'metrics':
  password    => Sensitive('Kv7-ruQ2-mzt8'),
  description => 'Java applications that write metrics',
}

opensearch_role_mapping { 'metrics_writer':
  users   => ['metrics'],
  require => Opensearch_internal_user['metrics'],
}
```

What the permissions allow:

* `write`: the built-in action group for `indices:data/write*`, which covers
  index, update, delete and the shard part of bulk requests.
* `create_index`: the applications can create a new `metrics-…` index the
  first time they write to it.
* `indices:admin/mapping/put`: dynamic mapping can add new fields. Without
  it, documents with new fields are rejected.
* Cluster permission `indices:data/write/bulk`: Java clients send almost
  everything as bulk requests, and OpenSearch checks bulk at the cluster
  level too.

The role grants no read access. If the applications need to read as well,
use `crud` instead of `write`.

Notes:

* The role mapping must have the same name as the role. It automatically
  depends on the `opensearch_role` with that name. The `require` on the user
  is optional, because a mapping may name a user that doesn't exist yet. It
  only makes the order clear.
* OpenSearch checks new passwords: by default they must be strong
  (`plugins.security.restapi.password_score_based_validation_strength`) and
  not similar to the user name. `metricstest` is rejected as "Weak
  password", `Metrics-Test-2026` as "Password is similar to user name".
* The password is only used when the user is created. Puppet ignores it
  afterwards: changing it in the manifest or in OpenSearch causes no change.
* `Sensitive()` keeps the password out of logs and reports, but it is still
  plain text in the manifest. Consider Hiera with eyaml, or `password_hash`
  with a bcrypt hash (e.g. from
  `plugins/opensearch-security/tools/hash.sh` on an OpenSearch node).
* Instead of a role mapping, a role can be assigned to the user directly
  with `opendistro_security_roles => ['metrics_writer']`.

## Data streams

The applications that use the user `metrics` (see above) write to the data
stream `metrics`. Its backing indices roll over daily and are deleted after
30 days.

```puppet
opensearch_ism_policy { 'metrics_daily':
  description   => 'Daily rollover, deletion after 30 days',
  default_state => 'hot',
  states        => [
    {
      'name'        => 'hot',
      'actions'     => [{ 'rollover' => { 'min_index_age' => '1d' } }],
      'transitions' => [{ 'state_name' => 'delete', 'conditions' => { 'min_index_age' => '30d' } }],
    },
    {
      'name'        => 'delete',
      'actions'     => [{ 'delete' => {} }],
      'transitions' => [],
    },
  ],
  ism_template  => [{ 'index_patterns' => ['metrics'], 'priority' => 100 }],
}

opensearch_index_template { 'metrics':
  index_patterns => ['metrics'],
  data_stream    => {},
  priority       => 100,
  template       => {
    'settings' => { 'number_of_shards' => 1, 'number_of_replicas' => 1 },
  },
}

opensearch_data_stream { 'metrics':
  require => Opensearch_ism_policy['metrics_daily'],
}
```

How it works:

* The index template with `data_stream => {}` makes `metrics` a data stream.
  Every document needs a `@timestamp` field. Data streams are append-only:
  the applications must write with `op_type` `create` (in a bulk request:
  `{"create": {...}}`). Updating or deleting single documents is only
  possible on the backing indices, by ID.
* `opensearch_data_stream` creates the data stream with its first backing
  index. It automatically depends on the index template with the same name.
  The `require` on the ISM policy makes sure that the policy exists when the
  first backing index is created; ISM only attaches policies to new indices.
* The ISM policy attaches to every backing index of the data stream, because
  its `ism_template` matches the data stream name. The `hot` state rolls the
  data stream over when the current backing index is one day old. 30 days
  after its creation, a backing index moves to the state `delete` and is
  deleted.
* The role `metrics_writer` from the previous section covers the data stream,
  because `metrics*` matches `metrics`. Since Puppet creates the data stream,
  the applications don't need permission to create indices.

Things to know:

* **No dates in index names.** The backing indices are always named
  `.ds-metrics-000001`, `.ds-metrics-000002`, …; OpenSearch has no setting
  for this. The creation date of each index shows in
  `GET _cat/indices/.ds-metrics-*?v&h=index,creation.date.string`. If you
  need dates in the names, use an alias with date math index names
  (`<metrics-{now/d}-000001>`) and `rollover_alias` instead of a data stream.
* **Rollover is not at midnight.** ISM checks its conditions every 5 minutes
  (setting `plugins.index_state_management.job_interval`), so a rollover
  happens a few minutes after the index has turned one day old. The time of
  day therefore shifts a little every day.
* **Retention.** `min_index_age` counts from the creation of the backing
  index. An index is deleted 30 days after it was created, i.e. 29 days after
  it received the last document. To keep 30 full days, use
  `'min_rollover_age' => '30d'` in the transition instead.
* **Changing the policy** doesn't affect backing indices that already exist;
  they keep the version of the policy they started with.
* **`ensure => absent` on the data stream deletes all its data.** To remove
  everything, delete the data stream before the index template:
  `opensearch_data_stream { 'metrics': ensure => absent, before => Opensearch_index_template['metrics'] }`.

## Single indices and aliases

Most indices should come from index templates and data streams. For single,
long-lived indices, such as a lookup index, use `opensearch_index`. Aliases
let applications use a stable name while the index behind it changes.

```puppet
opensearch_index { 'customers-v2':
  settings => { 'number_of_shards' => 1, 'number_of_replicas' => 1, 'refresh_interval' => '5s' },
  mappings => {
    'dynamic'    => 'strict',
    'properties' => {
      'name'    => { 'type' => 'text' },
      'email'   => { 'type' => 'keyword' },
      'country' => { 'type' => 'keyword' },
    },
  },
}

opensearch_alias { 'customers':
  indices     => ['customers-v2'],
  write_index => 'customers-v2',
}

opensearch_alias { 'customers-eu':
  indices => ['customers-v2'],
  filter  => { 'terms' => { 'country' => ['de', 'fr', 'nl'] } },
}
```

* Aliases automatically depend on the indices they name.
* To switch to a new index, change `indices` and `write_index`. Puppet
  moves the alias in one atomic request, so readers never see no index or
  both.
* `settings` and `mappings` only compare what you specify. New mapping
  fields are added; the type of an existing field can't be changed.
* Static settings such as `codec` can only be changed while the index is
  closed: set `state => 'closed'` together with the setting. Puppet closes
  the index first, then changes the setting.
* `ensure => absent` deletes the index and its data.

## Ingest and search pipelines

An ingest pipeline that the index template of the data stream `metrics`
(see above) uses by default, and a search pipeline that hides internal
documents:

```puppet
opensearch_ingest_pipeline { 'metrics_enrich':
  description => 'Adds the environment and normalizes the level',
  processors  => [
    { 'set' => { 'field' => 'environment', 'value' => 'production' } },
    { 'lowercase' => { 'field' => 'level', 'ignore_missing' => true } },
  ],
  on_failure  => [
    { 'set' => { 'field' => 'ingest_error', 'value' => '{{ _ingest.on_failure_message }}' } },
  ],
}

opensearch_index_template { 'metrics':
  index_patterns => ['metrics'],
  data_stream    => {},
  priority       => 100,
  template       => {
    'settings' => { 'default_pipeline' => 'metrics_enrich' },
  },
  require        => Opensearch_ingest_pipeline['metrics_enrich'],
}

opensearch_search_pipeline { 'public_only':
  description        => 'Hides internal documents',
  request_processors => [
    { 'filter_query' => { 'query' => { 'bool' => { 'must_not' => { 'term' => { 'internal' => true } } } } } },
  ],
}
```

* Processors are compared in their order; a different order is a change.
* Searches use the search pipeline with `?search_pipeline=public_only`, or
  for all searches on an index with the index setting
  `index.search.default_pipeline`.
* `_meta` is not supported for ingest pipelines: OpenSearch 3 rejects it.

## Stored scripts and search templates

```puppet
opensearch_stored_script { 'boost_by_popularity':
  lang    => 'painless',
  source  => "_score * Math.log(2 + doc['popularity'].value)",
  context => 'score',
}

opensearch_stored_script { 'find_by_host':
  lang   => 'mustache',
  source => {
    'query' => { 'term' => { 'host.name' => '{{host}}' } },
    'size'  => '{{size}}',
  },
}
```

* With `context`, OpenSearch compiles the script when storing it and rejects
  invalid scripts. Without it, errors only show when the script is used.
* A search template can be a Hash (as above) or JSON text; both are compared
  as data. Use it with
  `GET metrics/_search/template {"id": "find_by_host", "params": {"host": "web1", "size": 10}}`.

## Tenants, multi-tenancy and the allow list

Tenants for OpenSearch Dashboards, the multi-tenancy settings, and an allow
list that limits the REST API. The allow list needs a connection with the
admin certificate; here the connection `default` uses it.

```puppet
class { 'manage_opensearch':
  client_cert => '/etc/opensearch/admin.pem',
  client_key  => '/etc/opensearch/admin-key.pem',
  ca_file     => '/etc/opensearch/root-ca.pem',
}

opensearch_tenant { ['operations', 'development']:
  description => 'Team tenant',
}

opensearch_tenancy_config { 'default':
  multitenancy_enabled   => true,
  private_tenant_enabled => false,
  default_tenant         => 'operations',
}

opensearch_role { 'operations_dashboards':
  tenant_permissions => [
    { 'tenant_patterns' => ['operations'], 'allowed_actions' => ['kibana_all_write'] },
  ],
}

opensearch_allowlist { 'default':
  enabled  => true,
  requests => {
    '/_cluster/health' => ['GET'],
    '/_cat/indices'    => ['GET'],
    '/metrics/_bulk'   => ['POST'],
  },
}
```

* The title of `opensearch_tenancy_config` and `opensearch_allowlist` is the
  connection name: these settings exist once per cluster.
* `opensearch_tenancy_config` automatically depends on the tenants it names.
* `preferred_tenants` exists only in OpenSearch 3; OpenSearch 2 rejects it.
* **Careful with `enabled => true`:** every user except the super admin
  (admin certificate) can then only call the listed endpoints, including
  users of applications and of OpenSearch Dashboards. List everything they
  need before enabling it. If Puppet connects with a user and password,
  add a second connection with the admin certificate for the allow list
  (`opensearch_allowlist { 'superadmin': ... }`); the user of the
  `default` connection is then restricted too.
