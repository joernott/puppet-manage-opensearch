# Changes some attributes. The password differs from the initial one but must
# be ignored.
opensearch_action_group { 'it_logs_read':
  allowed_actions => ['indices:data/read/search*'],
}

opensearch_role { 'it_logs_reader':
  index_permissions => [{ index_patterns => ['logs-*'], allowed_actions => ['read'] }],
}

opensearch_role_mapping { 'it_logs_reader':
  users => ['it_alice', 'it_bob'],
}

opensearch_internal_user { 'it_alice':
  password      => Sensitive('Some-Other-Pw-2026!'),
  backend_roles => ['ldap-readers', 'ldap-writers'],
}
