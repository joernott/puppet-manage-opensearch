opensearch_index_template { ['it_logs', 'it_stream']: ensure => absent }
opensearch_ism_policy { 'it_retention': ensure => absent }
