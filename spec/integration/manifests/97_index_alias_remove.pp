opensearch_alias { ['it-orders', 'it-orders-eu']: ensure => absent }
opensearch_index { ['it-orders-1', 'it-orders-2', 'it-orders-3']: ensure => absent }
