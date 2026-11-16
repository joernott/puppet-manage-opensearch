opensearch_index_template { 'it_logs':
  index_patterns => ['it-logs-*'],
  priority       => 10,
  version        => 3,
  meta           => { 'owner' => 'ops' },
  template       => {
    'settings' => { 'number_of_shards' => 1, 'index' => { 'refresh_interval' => '5s' } },
    'mappings' => { 'properties' => { 'msg' => { 'type' => 'text' }, 'ts' => { 'type' => 'date' } } },
    'aliases'  => { 'it-logs' => {} },
  },
}

opensearch_index_template { 'it_stream':
  index_patterns => ['it-stream-*'],
  data_stream    => {},
  template       => { 'mappings' => { 'dynamic' => false } },
}

opensearch_ism_policy { 'it_retention':
  description   => 'integration test',
  default_state => 'hot',
  states        => [
    {
      'name'        => 'hot',
      'actions'     => [{ 'rollover' => { 'min_size' => '10gb' } }],
      'transitions' => [{ 'state_name' => 'delete', 'conditions' => { 'min_index_age' => '30d' } }],
    },
    { 'name' => 'delete', 'actions' => [{ 'delete' => {} }], 'transitions' => [] },
  ],
  ism_template  => [{ 'index_patterns' => ['it-logs-*'], 'priority' => 5 }],
}
