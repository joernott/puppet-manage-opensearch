# puppet-manage_opensearch

Manages objects inside an existing OpenSearch cluster through its REST API:

| Type | Manages |
|---|---|
| `opensearch_role` | security roles |
| `opensearch_role_mapping` | mappings of users, backend roles and hosts to roles |
| `opensearch_action_group` | security action groups |
| `opensearch_internal_user` | users of the internal user database |
| `opensearch_index_template` | composable index templates (`_index_template`) |
| `opensearch_ism_policy` | Index State Management policies |

It also provides the structured fact `opensearch`. Installing and configuring
OpenSearch itself is left to other modules.

Supported: OpenSearch 2.x and 3.x (tested with 2.19 and 3.9), OpenVox/Puppet
8 and 9.

## Setup

Include the class `manage_opensearch` on the OpenSearch nodes. It writes the
connection settings to `/etc/puppetlabs/manage_opensearch/connections.yaml`
(root only, mode 0600). By default it connects to the local node at
`https://<fqdn>:9200`:

```puppet
class { 'manage_opensearch':
  username => 'admin',
  password => Sensitive('secret'),
  ca_file  => '/etc/opensearch/root-ca.pem',
}
```

Instead of basic authentication, you can use a client certificate
(`client_cert` and `client_key`), e.g. the admin certificate. The user needs
access to the security REST API for the security types.

Declare the `opensearch_*` resources on **one** node of the cluster. Declaring
them on every node gives the same result, but causes needless API calls and
competing Puppet runs.

## Usage

```puppet
opensearch_action_group { 'logs_read':
  allowed_actions => ['indices:data/read*', 'indices:admin/mappings/get'],
  type            => 'index',
}

opensearch_role { 'logs_reader':
  cluster_permissions => ['cluster_composite_ops_ro'],
  index_permissions   => [
    { index_patterns => ['logs-*'], allowed_actions => ['logs_read'], fls => ['~secret'] },
  ],
}

opensearch_role_mapping { 'logs_reader':
  backend_roles => ['ldap-logs-readers'],
}

opensearch_internal_user { 'logstash':
  password                  => Sensitive('initial-secret'),
  opendistro_security_roles => ['logs_writer'],
}

opensearch_index_template { 'logs':
  index_patterns => ['logs-*'],
  priority       => 100,
  template       => {
    'settings' => { 'number_of_shards' => 1, 'refresh_interval' => '5s' },
    'mappings' => { 'properties' => { 'message' => { 'type' => 'text' } } },
  },
}

opensearch_ism_policy { 'logs_retention':
  default_state => 'hot',
  states        => [
    {
      'name'        => 'hot',
      'actions'     => [{ 'rollover' => { 'min_size' => '10gb' } }],
      'transitions' => [{ 'state_name' => 'delete', 'conditions' => { 'min_index_age' => '30d' } }],
    },
    { 'name' => 'delete', 'actions' => [{ 'delete' => {} }], 'transitions' => [] },
  ],
  ism_template  => [{ 'index_patterns' => ['logs-*'], 'priority' => 100 }],
}
```

All types can be listed with `puppet resource`, e.g. `puppet resource opensearch_role`.

### Behaviour worth knowing

* **Only what you set is managed.** Attributes that a resource doesn't set
  stay as they are in the cluster.
* **Order doesn't matter** for permission lists, users, backend roles and
  index patterns. Index settings may be nested or dotted, with or without the
  `index.` prefix, and as numbers or strings.
* **Passwords are only set when a user is created.** After that, Puppet
  ignores the password: changing it in the manifest has no effect, and a
  password changed in OpenSearch is not reset.
* **Built-in objects** (reserved, static or hidden, such as the role
  `all_access`) are not listed and cannot be changed. Purging with
  `resources { 'opensearch_role': purge => true }` leaves them alone.
* **ISM policies** are compared generously, because OpenSearch adds defaults
  (such as `retry` settings) to stored policies. A policy is in sync when
  everything the manifest specifies is present with the same value. Lists must
  match in length and order. Removing a single key from a hash in the manifest
  is therefore not detected. Updating a policy does not change indices already
  managed by an older version of it.
* **Several clusters:** further connections can be added with the class
  parameter `connections`. Address resources in them with titles like
  `'other/logs_reader'` or the `connection` parameter. Listing and purging
  query every configured connection.

## The `opensearch` fact

Available on nodes with the class (from the second Puppet run on, after the
connection file exists):

```yaml
opensearch:
  cluster:
    health: {}   # GET _cluster/health
    state:       # brief overview
      cluster_name: docker-cluster
      cluster_uuid: zprsEmGVSLOUTw3CZvJNLQ
      version: 3.9.0            # OpenSearch version
      state_version: 42         # version of the cluster state
      cluster_manager_node: -bVL_XxbSxaOnCpcj_WMTw
      nodes:
        -bVL_XxbSxaOnCpcj_WMTw: { name: os1, roles: [cluster_manager, data, ingest] }
    nodes: [os1, os2]           # node names
    node: {}                    # GET _nodes/_local: this node, plus its 'id'
```

Settings whose names contain `password`, `secret`, `token` or `credential` are
removed from `node`. If the cluster is unreachable, the affected parts are left
out with a warning; the Facter run doesn't fail.

## Reference

See [REFERENCE.md](REFERENCE.md).

## Development

Tests run in containers, so Docker is the only requirement.

```sh
# Lint, syntax and unit tests (Ruby 3.2 + OpenVox 8 by default)
scripts/ruby.sh bundle install
scripts/ruby.sh bundle exec rake test rubocop
RUBY_VERSION=4.0 OPENVOX_GEM_VERSION='~> 9.0' scripts/ruby.sh bundle exec rake test

# Integration test: real OpenVox agent against a real OpenSearch container
scripts/integration-test.sh 3.9.0 8     # OpenSearch version, OpenVox major
```

The integration test applies each manifest in
[spec/integration/manifests](spec/integration/manifests) twice. The first run
must change something and the second nothing. Afterwards it checks the result
through the API.

Regenerate `REFERENCE.md` with `scripts/ruby.sh bundle exec rake strings:generate:reference`.
