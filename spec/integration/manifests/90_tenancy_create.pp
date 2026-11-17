opensearch_tenant { ['it_ops', 'it_dev']:
  description => 'integration test',
}

# preferred_tenants exists since OpenSearch 3.
$preferred = Integer($facts['opensearch_major']) >= 3 ? {
  true    => { 'preferred_tenants' => ['it_dev', 'it_ops'] },
  default => {},
}

opensearch_tenancy_config { 'default':
  default_tenant => 'it_ops',
  *              => $preferred,
}

# Only works with the admin certificate (connection "superadmin").
opensearch_allowlist { 'superadmin':
  enabled  => false,
  requests => { '/_cat/nodes' => ['GET'], '/_cluster/health' => ['GET'] },
}
