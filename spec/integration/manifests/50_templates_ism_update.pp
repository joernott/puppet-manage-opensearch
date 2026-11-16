# Changes some attributes; the others (meta, aliases, ism_template, ...) must
# stay as they are.
opensearch_index_template { 'it_logs':
  priority => 20,
  template => {
    'settings' => { 'index.number_of_shards' => '2', 'refresh_interval' => '5s' },
    'mappings' => { 'properties' => { 'msg' => { 'type' => 'text' }, 'ts' => { 'type' => 'date' } } },
    'aliases'  => { 'it-logs' => {} },
  },
}

opensearch_ism_policy { 'it_retention':
  states => [
    {
      'name'        => 'hot',
      'actions'     => [{ 'rollover' => { 'min_size' => '20gb' } }],
      'transitions' => [{ 'state_name' => 'delete', 'conditions' => { 'min_index_age' => '60d' } }],
    },
    { 'name' => 'delete', 'actions' => [{ 'delete' => {} }], 'transitions' => [] },
  ],
}
