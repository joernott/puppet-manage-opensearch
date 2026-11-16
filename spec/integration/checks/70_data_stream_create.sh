# Sourced by run.sh after 70_data_stream_create.pp.
api GET _data_stream/metrics | grep -q '"index_name":".ds-metrics-000001"' || fail 'data stream metrics missing'
# The user metrics can write with its own permissions, as a Java client would (bulk, op_type create).
result=$(printf '%s\n' '{"create":{"_index":"metrics"}}' '{"@timestamp":"2026-11-16T10:00:00Z","value":1}' |
  curl -sk -u 'metrics:Kv7-ruQ2-mzt8' -H 'Content-Type: application/x-ndjson' --data-binary @- 'https://localhost:9200/_bulk?refresh=true')
echo "$result" | grep -q '"errors":false' || fail "user metrics cannot write to the data stream: $result"
# The ISM policy manages the backing index.
api GET _plugins/_ism/explain/.ds-metrics-000001 | grep -q '"policy_id":"metrics_daily"' || fail 'ISM policy not attached to the backing index'
puppet resource opensearch_data_stream | grep -q "generation => 1" || fail 'puppet resource does not list the data stream'
true
