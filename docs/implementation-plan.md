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
- `create` uses `PUT`, `delete` uses `DELETE`.
- **Partial management:** attributes the manifest doesn't set must survive an
  update. Security objects are updated with `PATCH` operations for the managed
  attributes only. Index templates and ISM policies only have `PUT`, so their
  update sends the stored object with the managed attributes replaced.
- **Reserved/static/hidden** entries (e.g. `all_access`, `kibana_user`) are
  left out of `get`. They can't be changed through the API anyway, and purging
  then skips them. Declaring one fails with the API's "reserved" error.

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
| `opensearch_internal_user` | `_plugins/_security/api/internalusers/{name}` | `password` (Sensitive) or `password_hash` (bcrypt), `backend_roles`, `opendistro_security_roles`, `attributes`, `description` | `password`/`password_hash` are used only when the user is created and are never compared afterwards (decision 3); `update` sends the existing user without a password, so it is kept; autorequire listed roles |
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

Ruby is not installed on the VM. `scripts/ruby.sh` runs every command in an
official `ruby:<version>` container as the calling user, with gems cached in a
Docker volume per Ruby version. This needs no sudo and pins the Ruby version
per OpenVox major, matching what the agent packages bundle: Ruby 3.2 for
OpenVox 8, Ruby 4.0 for OpenVox 9.

Tooling follows Vox Pupuli conventions, not PDK, because PDK is tied to
Perforce Puppet:
- `Gemfile` with `voxpupuli-test` (rspec-puppet, rubocop, puppet-lint,
  metadata-json-lint, openvox-strings), the `openvox` gem (major selected via
  `OPENVOX_GEM_VERSION`) and `webmock`
- `Rakefile` from voxpupuli-test (`rake test`, `rake lint`, `rake rubocop`,
  `rake strings:generate:reference`)

Test layers:
1. **Unit** (`spec/unit`): client, normalization and providers against
   `webmock` stubs, plus rspec-puppet for the class and type validation.
2. **Integration** (`spec/integration`, run on the VM and in CI):
   `scripts/integration-test.sh <opensearch> <openvox>` starts a single-node
   OpenSearch container with the security plugin enabled
   (`opensearchproject/opensearch:2.19.7` or `:3.9.0`, heap 512 MB). It then
   runs `puppet apply` in a container with the **real OpenVox agent package**
   (`spec/integration/Dockerfile`), so the bundled Ruby, Resource API and
   Facter versions are tested. Each manifest in `spec/integration/manifests` is
   applied **twice**: the first run must exit 2 (changes), the second 0 (no
   changes), which proves idempotence. Then `spec/integration/checks/*.sh`
   verify the result through the API, including that unmanaged attributes and
   passwords changed outside Puppet are kept. Beaker/Litmus is not needed.
3. **CI**: GitHub Actions with a unit matrix (Ruby 3.2 + OpenVox 8, Ruby 4.0 +
   OpenVox 9) and an integration matrix (OpenSearch 2.19.7 / 3.9.0 × OpenVox
   8 / 9) that runs the same script.

## 6. Milestones

1. **Dev environment**: Ruby containers on the VM, pull OpenSearch 2 + 3 images,
   smoke test with curl. *(done)*
2. **Skeleton**: `metadata.json`, Gemfile, Rakefile, `.rubocop.yml`, `.fixtures.yml`,
   spec helpers, `.github/workflows/ci.yml`, `.gitignore`, README stub. Green CI on
   an empty module. *(done)*
3. **Core**: `client.rb`, `config.rb`, `normalize.rb`, class `manage_opensearch`.
   Unit-tested. *(done)*
4. **Facts**, with unit tests plus a check against the containers. *(done)*
5. **Types**, one at a time with unit and integration tests each, from simplest
   to most complex: action_group → role → role_mapping → internal_user →
   index_template → ism_policy. *(done)*
6. **Docs and release**: README with usage, `REFERENCE.md` via puppet-strings,
   `CHANGELOG.md` *(done)*; tag `v0.1.0`, `rake build` for the Forge tarball
   *(open)*.

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

## 8. Implementation notes

Findings during implementation that changed or refined the plan:

- **Composite namevars:** `name` and `connection` are both namevars. Titles
  are `name` (connection `default`) or `connection/name`. `get` must return
  the title as `connection/name`, because the Resource API checks that the
  title parses back to both namevars.
- **Password:** `password` is a property, not a parameter, so Puppet redacts
  it. Through the `custom_insync` feature, the provider always reports it in
  sync (decision 3). Updates use `PATCH` without the password, so a password
  changed outside Puppet stays.
- **ISM policies:** OpenSearch adds `retry` defaults to every action,
  `copy_alias: false` to rollovers and timestamps to `ism_template`.
  `states`, `ism_template` and `error_notification` are therefore compared
  with `custom_insync` as "manifest is a deep subset of the stored policy"
  (lists element by element). The downside: removing a single hash key in the
  manifest is not detected.
- **Index templates:** settings come back nested under `index` with string
  values, `composed_of` defaults to `[]`, and `data_stream: {}` comes back
  with the default `timestamp_field`. All of this is normalized on both sides,
  so plain equality works.
- **Facts:** `_cluster/state` doesn't contain node roles; they come from
  `_nodes?filter_path=nodes.*.roles`. Settings with password/secret/token/
  credential in the name are removed from `node`. The fact is about 55 KB per
  node, mostly from `node` (`plugins`, `modules`, `thread_pool`, `jvm`,
  `aggregations`).
- **Providers use methods instead of constants**, because Puppet loads
  provider files twice, which causes "already initialized constant" warnings.
- **Type files are plain literals** (no helper calls, no `%w[]`), because
  puppet-strings only documents Resource API types written that way.
- **Dev VM disk:** OpenSearch blocks index creation above the flood-stage disk
  watermark. The test container therefore disables disk thresholds.
