# Sourced by run.sh after 94_pipelines_scripts_remove.pp.
for path in _ingest/pipeline/it_enrich _search/pipeline/it_public _scripts/it_score _scripts/it_template; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" "https://localhost:9200/$path")
  [ "$code" = 404 ] || fail "$path still exists (HTTP $code)"
done
true
