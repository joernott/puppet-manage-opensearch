# Static settings (codec) can only be changed on a closed index.
opensearch_index { 'it-orders-1':
  state    => 'closed',
  settings => { 'codec' => 'best_compression' },
}

opensearch_index { 'it-orders-2':
  settings => { 'refresh_interval' => '10s' },
  mappings => { 'properties' => { 'amount' => { 'type' => 'float' } } },
}

opensearch_index { 'it-orders-3':
  settings => { 'number_of_shards' => 1, 'number_of_replicas' => 0 },
}

opensearch_alias { 'it-orders':
  indices     => ['it-orders-2', 'it-orders-3'],
  write_index => 'it-orders-3',
}

opensearch_alias { 'it-orders-eu':
  indices => ['it-orders-2', 'it-orders-3'],
}
