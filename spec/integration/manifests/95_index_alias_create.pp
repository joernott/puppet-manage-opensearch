opensearch_index { 'it-orders-1':
  settings => { 'number_of_shards' => 1, 'number_of_replicas' => 0 },
  mappings => {
    'dynamic'    => 'strict',
    'properties' => { 'id' => { 'type' => 'keyword' }, 'region' => { 'type' => 'keyword' } },
  },
}

opensearch_index { 'it-orders-2':
  settings => { 'index' => { 'number_of_shards' => '1', 'number_of_replicas' => '0', 'refresh_interval' => '5s' } },
  mappings => { 'properties' => { 'id' => { 'type' => 'keyword' }, 'region' => { 'type' => 'keyword' } } },
}

opensearch_alias { 'it-orders':
  indices     => ['it-orders-1', 'it-orders-2'],
  write_index => 'it-orders-2',
}

opensearch_alias { 'it-orders-eu':
  indices => ['it-orders-1', 'it-orders-2'],
  filter  => { 'term' => { 'region' => 'eu' } },
}
