opensearch_tenant { 'it_ops':
  description => 'operations',
}

opensearch_tenant { 'it_dev':
  ensure => absent,
}

# preferred_tenants exists since OpenSearch 3.
$preferred = Integer($facts['opensearch_major']) >= 3 ? {
  true    => { 'preferred_tenants' => ['it_ops'] },
  default => {},
}

opensearch_tenancy_config { 'default':
  private_tenant_enabled => false,
  before                 => Opensearch_tenant['it_dev'],
  *                      => $preferred,
}

opensearch_allowlist { 'superadmin':
  requests => { '/_cat/nodes' => ['GET'], '/_cat/indices' => ['HEAD', 'GET'] },
}
