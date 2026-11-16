# A data stream must be deleted before its index template.
opensearch_data_stream { 'metrics':
  ensure => absent,
  before => Opensearch_index_template['metrics'],
}
opensearch_index_template { 'metrics': ensure => absent }
opensearch_ism_policy { 'metrics_daily': ensure => absent }
opensearch_role_mapping { 'metrics_writer': ensure => absent }
opensearch_role { 'metrics_writer': ensure => absent }
opensearch_internal_user { 'metrics': ensure => absent }
