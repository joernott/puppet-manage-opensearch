# Sourced by run.sh after 60_templates_ism_remove.pp.
for path in _index_template/it_logs _index_template/it_stream _plugins/_ism/policies/it_retention; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" "https://localhost:9200/$path")
  [ "$code" = 404 ] || fail "$path still exists (HTTP $code)"
done
