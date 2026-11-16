# Sourced by run.sh after 80_data_stream_remove.pp.
for path in _data_stream/metrics _index_template/metrics _plugins/_ism/policies/metrics_daily \
  _plugins/_security/api/internalusers/metrics _plugins/_security/api/roles/metrics_writer; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" "https://localhost:9200/$path")
  [ "$code" = 404 ] || fail "$path still exists (HTTP $code)"
done
api GET '_cat/indices/.ds-metrics-*' | grep -q . && fail 'backing indices of metrics still exist'
true
