# puppet-manage_opensearch

Manages objects inside an existing OpenSearch cluster through its REST API:
security roles, role mappings, action groups, internal users, index templates
and ISM policies. It also provides an `opensearch` structured fact. Installing
OpenSearch itself is left to other modules.

Supports OpenSearch 2.x and 3.x with OpenVox/Puppet 8 and 9.

> **Status:** under development towards 0.1.0. See
> [docs/concept.md](docs/concept.md) and
> [docs/implementation-plan.md](docs/implementation-plan.md).

## Usage

Include the class on the OpenSearch nodes. By default it connects to the local
node at `https://<fqdn>:9200`:

```puppet
class { 'manage_opensearch':
  username => 'admin',
  password => Sensitive('secret'),
  ca_file  => '/etc/opensearch/root-ca.pem',
}
```

## Development

Tests run in Ruby containers, so the only requirement is Docker:

```sh
scripts/ruby.sh bundle install
scripts/ruby.sh bundle exec rake test rubocop
# other Ruby / OpenVox versions:
RUBY_VERSION=3.4 OPENVOX_GEM_VERSION='~> 9.0' scripts/ruby.sh bundle exec rake test
```
