opensearch_role_mapping { 'it_logs_reader': ensure => absent }
opensearch_internal_user { ['it_alice', 'it_bob']: ensure => absent }
opensearch_role { 'it_logs_reader':
  ensure  => absent,
  require => [Opensearch_role_mapping['it_logs_reader'], Opensearch_internal_user['it_alice']],
}
opensearch_action_group { 'it_logs_read':
  ensure  => absent,
  require => Opensearch_role['it_logs_reader'],
}
