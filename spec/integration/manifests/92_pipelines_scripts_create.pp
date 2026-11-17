opensearch_ingest_pipeline { 'it_enrich':
  description => 'integration test',
  processors  => [
    { 'set' => { 'field' => 'environment', 'value' => 'test' } },
    { 'lowercase' => { 'field' => 'level', 'ignore_missing' => true } },
  ],
  on_failure  => [{ 'set' => { 'field' => 'error', 'value' => '{{ _ingest.on_failure_message }}' } }],
  version     => 1,
}

opensearch_search_pipeline { 'it_public':
  description        => 'integration test',
  request_processors => [{ 'filter_query' => { 'query' => { 'term' => { 'visibility' => 'public' } } } }],
}

opensearch_stored_script { 'it_score':
  lang    => 'painless',
  source  => "_score * params['factor']",
  context => 'score',
}

opensearch_stored_script { 'it_template':
  lang   => 'mustache',
  source => { 'query' => { 'term' => { 'host' => '{{host}}' } }, 'size' => '{{size}}' },
}
