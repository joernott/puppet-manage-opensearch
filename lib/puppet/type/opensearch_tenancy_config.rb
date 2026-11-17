# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'opensearch_tenancy_config',
  docs: <<~DOC,
    @summary Manages the multi-tenancy configuration of OpenSearch Dashboards.

    The configuration exists once per cluster, so the title is the name of a
    connection from the class `manage_opensearch`. It cannot be removed.
    Attributes that are not set are kept as they are in the cluster.

    @example
      opensearch_tenancy_config { 'default':
        multitenancy_enabled   => true,
        private_tenant_enabled => false,
        default_tenant         => 'operations',
        preferred_tenants      => ['operations', 'global_tenant'],
      }
  DOC
  features: ['canonicalize', 'simple_get_filter'],
  autorequire: {
    file: '/etc/puppetlabs/manage_opensearch/connections.yaml',
    opensearch_tenant: ['$default_tenant', '$preferred_tenants'],
  },
  attributes: {
    connection: {
      type: 'Pattern[/\A[a-z0-9_]+\z/]',
      desc: 'The connection from the class manage_opensearch to use.',
      behaviour: :namevar,
    },
    multitenancy_enabled: {
      type: 'Optional[Boolean]',
      desc: 'Whether multi-tenancy is enabled in OpenSearch Dashboards.',
    },
    private_tenant_enabled: {
      type: 'Optional[Boolean]',
      desc: 'Whether users have a private tenant.',
    },
    default_tenant: {
      type: 'Optional[String[1]]',
      desc: 'The tenant OpenSearch Dashboards opens by default. It must exist.',
    },
    sign_in_options: {
      type: "Optional[Array[Enum['BASIC', 'SAML', 'OPENID', 'ANONYMOUS']]]",
      desc: 'Sign-in options shown by OpenSearch Dashboards. Each needs a matching authentication domain. The order does not matter.',
    },
    preferred_tenants: {
      type: 'Optional[Array[String[1]]]',
      desc: 'Tenants listed first in the tenant selector, in this order. OpenSearch 3 and later.',
    },
  },
)
