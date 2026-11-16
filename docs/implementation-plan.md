# Implementation plan – manage_opensearch 0.1.0

Based on [concept.md](concept.md). Status: agreed, decisions are recorded in section 7.

## 1. Naming and scope

- Puppet module names cannot contain `-`. Forge name: `joernott-manage_opensearch`,
  main class `manage_opensearch`. GitHub repo: `joernott/puppet-manage_opensearch`.
- Targets: OpenSearch 2.x and 3.x, OpenVox/Puppet 8+. Only the `_plugins/...`
  API paths are used. The legacy `_opendistro/...` aliases are not used, so
  2.x and 3.x share one code path.
- Types in 0.1.0: `opensearch_action_group`, `opensearch_role`,
  `opensearch_role_mapping`, `opensearch_internal_user`,
  `opensearch_index_template` (composable `_index_template`, not legacy
  `_template`), `opensearch_ism_policy`.
- Structured facts under `opensearch.cluster.*`.
- Not in 0.1.0: creating tokens for users (see decision 2).

## 2. Architecture

```
manifests/init.pp                       class manage_opensearch: writes the connection config
lib/puppet_x/manage_opensearch/
  client.rb                             Net::HTTP wrapper: auth, TLS, retries, JSON, errors
  config.rb                             loads /etc/puppetlabs/manage_opensearch/connections.yaml
  normalize.rb                          shared normalization (sorting sets, settings flattening)
lib/puppet/type/opensearch_*.rb         Resource API type definitions
lib/puppet/provider/opensearch_*/opensearch_*.rb
lib/facter/opensearch.rb                structured fact
```

### Resource API instead of classic types/providers
`puppet-resource_api` ships with every OpenVox/Puppet 8 agent, so no extra gem
is needed on the nodes. Each type declares its attributes with Puppet data
types. Passwords use `Sensitive[String]`. Providers derive from
`Puppet::ResourceApi::SimpleProvider` and use the `canonicalize` feature to
normalize API responses before comparison.

- `get` fetches the full collection in one call (e.g. `GET
  _plugins/_security/api/roles`). That gives `puppet resource opensearch_role`
  and `resources { 'opensearch_role': purge => true }` for free.
- `create`/`update` use `PUT`, `delete` uses `DELETE`.
- **Partial management:** the security API's `PUT` replaces the whole object.
  To avoid wiping attributes the manifest doesn't set, `update` merges the
  `should` state over the current `is` state before sending.
- **Reserved/static/hidden** entries (e.g. `all_access`, `kibana_user`) are
  exposed read-only. `get` returns them with `reserved => true`. Changing them
  fails with a clear error, and purging skips them.

### Connections and credentials
Resources talk to a cluster through a named connection (parameter `connection`,
default `'default'`). The `manage_opensearch` class writes the connection
details to `/etc/puppetlabs/manage_opensearch/connections.yaml` (owner root,
mode 0600):

```puppet
class { 'manage_opensearch':
  connections => {
    'default' => {
      url         => 'https://localhost:9200',
      username    => 'admin',
      password    => Sensitive('…'),
      ca_file     => '/etc/opensearch/root-ca.pem',
      # alternatively client cert auth (needed for some security API calls):
      # client_cert => '…', client_key => '…',
      verify_tls  => true,
      timeout     => 30,
    },
  },
}
```

Providers read the file lazily at evaluation time. Each type autorequires the
`File` resource, so it works on the first run. The file is the only place the
password lives. It never appears in the catalog diff because it is `Sensitive`.

The module runs on an OpenSearch node (decision 5). The default connection URL
is `https://${facts['networking']['fqdn']}:9200`, so API calls and the facts
always go to the local node. Include the class on every node that should have
the facts. Declare the `opensearch_*` resources on one node only: declaring
them everywhere converges to the same result, but causes needless API traffic
and races between Puppet runs.

### HTTP client
Plain `Net::HTTP` with no extra gems. It handles:
- basic auth and client certificates, custom CA, and an optional switch to turn
  off TLS verification for lab setups
- JSON in and out
- retries with backoff on 503 and connection refused, so a cluster that is
  still starting doesn't fail the run immediately
- turning error bodies into readable `Puppet::Error` messages
- `GET /` once per run to detect the version (`version.number`). This allows
  2.x/3.x branches later, though 0.1.0 doesn't need any.

## 3. Resource details

The normalization notes cover the work needed for idempotence: a second run
must report zero changes.

| Type | Endpoint | Attributes | Normalization / gotchas |
|---|---|---|---|
| `opensearch_action_group` | `_plugins/_security/api/actiongroups/{name}` | `allowed_actions`, `type` (cluster/index/kibana), `description` | sort `allowed_actions` |
| `opensearch_role` | `_plugins/_security/api/roles/{name}` | `cluster_permissions`, `index_permissions` (array of hashes: `index_patterns`, `allowed_actions`, `dls`, `fls`, `masked_fields`), `tenant_permissions`, `description` | treat permission arrays as sets and sort them; fill API defaults (`dls: ""`, `fls: []`, …) on the `should` side |
| `opensearch_role_mapping` | `_plugins/_security/api/rolesmapping/{role}` | `backend_roles`, `and_backend_roles`, `hosts`, `users`, `description` | sort; autorequire `opensearch_role[title]` |
| `opensearch_internal_user` | `_plugins/_security/api/internalusers/{name}` | `password` (Sensitive) or `hash` (bcrypt), `backend_roles`, `opendistro_security_roles`, `attributes`, `description` | `password`/`hash` are used only when the user is created and are never compared afterwards (decision 3); `update` sends the existing user without a password, so it is kept; autorequire listed roles |
| `opensearch_index_template` | `_index_template/{name}` | `index_patterns`, `template` (settings/mappings/aliases), `composed_of`, `priority`, `version`, `meta`, `data_stream` | the API returns settings nested under `index` with **stringified values** (`"1"` instead of `1`) → flatten and stringify both sides |
| `opensearch_ism_policy` | `_plugins/_ism/policies/{id}` | `description`, `default_state`, `states`, `ism_template`, `error_notification` | updates need `?if_seq_no=…&if_primary_term=…` from the GET; strip server fields (`policy_id`, `last_updated_time`, `schema_version`, `seq_no`, …) |

Example:

```puppet
opensearch_role { 'logs_reader':
  ensure              => present,
  cluster_permissions => ['cluster_composite_ops_ro'],
  index_permissions   => [{ index_patterns => ['logs-*'], allowed_actions => ['read'] }],
}
opensearch_role_mapping { 'logs_reader':
  backend_roles => ['ldap-logs-readers'],
}
```

## 4. Facts

`lib/facter/opensearch.rb` builds one structured fact `opensearch`. It is
confined to hosts where `connections.yaml` exists, because Facter can't see
which classes a host includes. That means the facts appear from the second
Puppet run on. Only the `default` connection is used.

| Fact | Source |
|---|---|
| `opensearch.cluster.health` | `GET _cluster/health` |
| `opensearch.cluster.state` | brief overview only (decision 4): `cluster_name`, `cluster_uuid`, `version`, `cluster_manager_node`, and for each node its id, name and roles. Built from `GET _cluster/state/nodes,cluster_manager_node` plus `GET _nodes?filter_path=nodes.*.name,nodes.*.roles` for the roles. `version` is the OpenSearch version from `GET /`; the cluster-state version is added as `state_version`. The exact fields are checked against the 2.x and 3.x containers in milestone 4. |
| `opensearch.cluster.nodes` | `GET _nodes` → array of node names |
| `opensearch.cluster.node` | `GET _nodes/_local`. Because the connection points at the local node (decision 5), this is the node Puppet runs on. |

The fact uses short timeouts (5 s) and fails soft: on error it logs a warning,
returns what it has, and never breaks the Facter run.

## 5. Development and test setup (dev VM)

The dev VM is `claude@dev.vm.test.sf.thse.net` (Debian 13, 2 vCPU, 4 GB RAM,
Docker available, `vm.max_map_count` already OK). The workflow is the same as
for dcdash. Edit in the local Windows repo and commit locally. Sync the files
tracked by git to `~/puppet-manage_opensearch` on the VM and run tests there.
Pushes to GitHub happen from the Windows repo with a dedicated deploy key
(`~/.ssh/id_ed25519_manage_opensearch`, set as the repo-local `core.sshCommand`).

Install on the VM: `ruby-full`, `build-essential`, `bundler`. Tooling follows
Vox Pupuli conventions, not PDK, because PDK is tied to Perforce Puppet:
- `Gemfile` with `voxpupuli-test` (rspec-puppet, rubocop, puppet-lint,
  metadata-json-lint), `openvox` gem (8.x), `webmock`, `puppet-strings`
- `Rakefile` from voxpupuli-test (`rake test`, `rake lint`, `rake rubocop`,
  `rake strings:generate:reference`)

Test layers:
1. **Unit** (`spec/unit`): client, normalization and providers against
   `webmock` stubs, plus rspec-puppet for the class and type validation.
2. **Integration** (`spec/acceptance`, run on the VM and in CI): start single-node
   OpenSearch containers with the security plugin enabled
   (`opensearchproject/opensearch:2.19.x` and `:3.x`, heap 512 MB, one after the
   other, `OPENSEARCH_INITIAL_ADMIN_PASSWORD`). Then run `bundle exec puppet
   apply` with example manifests **twice**. The first run must converge; the
   second must exit 0 with `--detailed-exitcodes`, which proves idempotence.
   Then check via curl and run `puppet resource` / facter output checks.
   A helper script `scripts/integration-test.sh` drives this. Beaker/Litmus is
   not needed because the module runs nothing on the OpenSearch host itself.
3. **CI**: GitHub Actions with a unit job (Ruby 3.2 + newest Ruby, OpenVox 8)
   and an integration matrix (OpenSearch 2.x × 3.x) using service containers.

## 6. Milestones

1. **Dev environment**: Ruby/bundler on the VM, pull OpenSearch 2 + 3 images,
   smoke test with curl.
2. **Skeleton**: `metadata.json`, Gemfile, Rakefile, `.rubocop.yml`, `.fixtures.yml`,
   spec helpers, `.github/workflows/ci.yml`, `.gitignore`, README stub. Green CI on
   an empty module.
3. **Core**: `client.rb`, `config.rb`, `normalize.rb`, class `manage_opensearch`.
   Unit-tested.
4. **Facts**, with unit tests plus a check against the containers.
5. **Types**, one at a time with unit and integration tests each, from simplest
   to most complex: action_group → role → role_mapping → internal_user →
   index_template → ism_policy.
6. **Docs and release**: README with usage, `REFERENCE.md` via puppet-strings,
   `CHANGELOG.md`, tag `v0.1.0`, `rake build` for the Forge tarball.

## 7. Decisions (2026-11-16)

1. **Module name**: `joernott-manage_opensearch`, class `manage_opensearch`.
   The repo was renamed to `puppet-manage_opensearch`.
2. **User tokens**: not part of 0.1.0.
3. **Passwords**: a password (or hash) is set only when the user is created.
   After that it is ignored: it is not part of the change check and never sent
   on updates.
4. **`cluster.state` fact**: brief overview only: `cluster_name`,
   `cluster_uuid`, `version`, and the nodes with their ids, names and roles.
5. **Where it runs**: on an OpenSearch node. The connection defaults to the
   local node.
6. **Push access**: from Windows with a separate deploy key,
   `id_ed25519_manage_opensearch` (not the dcdash key).
