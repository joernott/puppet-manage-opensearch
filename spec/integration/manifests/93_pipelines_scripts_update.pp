opensearch_ingest_pipeline { 'it_enrich':
  processors => [
    { 'set' => { 'field' => 'environment', 'value' => 'test' } },
    { 'lowercase' => { 'field' => 'level', 'ignore_missing' => true } },
    { 'remove' => { 'field' => 'debug', 'ignore_missing' => true } },
  ],
  version    => 2,
}

opensearch_search_pipeline { 'it_public':
  description => 'public documents only',
}

opensearch_stored_script { 'it_score':
  source => "_score * params['factor'] * 2",
}

opensearch_stored_script { 'it_template':
  lang   => 'mustache',
  source => { 'query' => { 'term' => { 'host' => '{{host}}' } }, 'size' => 10 },
}
