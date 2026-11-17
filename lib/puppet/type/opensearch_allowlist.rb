# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_allowlist',
  docs: <<~DOC,
    @summary Manages the allow list of the security plugin.

    When the allow list is enabled, users other than the super admin can only
    call the listed endpoints with the listed methods.

    The allow list exists once per cluster, so the title is the name of a
    connection from the class `manage_opensearch`. **The connection must use
    the admin certificate** (`client_cert` and `client_key`); with a user and
    password, OpenSearch denies access even for `admin`. Listing
    (`puppet resource opensearch_allowlist`) skips connections without access.

    @example
      class { 'manage_opensearch':
        username    => 'admin',
        password    => Sensitive('secret'),
        connections => {
          'superadmin' => {
            'url'         => "https://${facts['networking']['fqdn']}:9200",
            'client_cert' => '/etc/opensearch/admin.pem',
            'client_key'  => '/etc/opensearch/admin-key.pem',
            'ca_file'     => '/etc/opensearch/root-ca.pem',
          },
        },
      }

      opensearch_allowlist { 'superadmin':
        enabled  => true,
        requests => {
          '/_cluster/health' => ['GET'],
          '/_cat/nodes'      => ['GET'],
        },
      }
  DOC
  features: ['canonicalize', 'simple_get_filter'],
  autorequire: {
    file: '/etc/puppetlabs/manage_opensearch/connections.yaml',
  },
  attributes: {
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use. It must use the admin certificate.',
      behaviour: :namevar,
    },
    enabled: {
      type: 'Optional[Boolean]',
      desc: 'Whether the allow list is enforced.',
    },
    requests: {
      type: "Optional[Hash[String[1], Array[Enum['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD']]]]",
      desc: 'Allowed requests: endpoint path => HTTP methods. The order of the methods does not matter.',
    },
  },
)
