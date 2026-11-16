opensearch_action_group { 'it_logs_read':
  allowed_actions => ['indices:data/read/search*', 'indices:admin/mappings/get'],
  type            => 'index',
  description     => 'integration test',
}

opensearch_role { 'it_logs_reader':
  cluster_permissions => ['cluster_composite_ops_ro'],
  index_permissions   => [
    {
      index_patterns  => ['logs-*', 'audit-*'],
      allowed_actions => ['it_logs_read', 'read'],
      fls             => ['~secret'],
      masked_fields   => ['ip'],
      dls             => '{"term": {"public": true}}',
    },
    { index_patterns => ['metrics-*'], allowed_actions => ['read'] },
  ],
  tenant_permissions  => [{ tenant_patterns => ['logs'], allowed_actions => ['kibana_all_read'] }],
  description         => 'integration test',
  require             => Opensearch_action_group['it_logs_read'],
}

opensearch_role_mapping { 'it_logs_reader':
  backend_roles => ['ldap-readers', 'ldap-auditors'],
  users         => ['it_alice'],
}

opensearch_internal_user { 'it_alice':
  password                  => Sensitive('Initial-Pw-2026!'),
  backend_roles             => ['ldap-readers'],
  opendistro_security_roles => ['it_logs_reader'],
  attributes                => { 'team' => 'ops', 'level' => 3 },
  description               => 'integration test',
}

# Without a description: the attributes it doesn't set stay unmanaged.
opensearch_internal_user { 'it_bob':
  password_hash => '$2y$12$88IFVl6IfIwCFh5aQYfOmuXVL9j2hz/GusQb35o.4sdTDAEMTOD.K',
}
