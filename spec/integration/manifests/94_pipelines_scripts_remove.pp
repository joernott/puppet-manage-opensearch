opensearch_ingest_pipeline { 'it_enrich': ensure => absent }
opensearch_search_pipeline { 'it_public': ensure => absent }
opensearch_stored_script { ['it_score', 'it_template']: ensure => absent }
