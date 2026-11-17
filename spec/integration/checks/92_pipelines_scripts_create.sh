# Sourced by run.sh after 92_pipelines_scripts_create.pp.
simulated=$(api POST _ingest/pipeline/it_enrich/_simulate -d '{"docs":[{"_source":{"level":"WARN"}}]}')
echo "$simulated" | grep -q '"environment":"test"' || fail "ingest pipeline does not set the environment: $simulated"
echo "$simulated" | grep -q '"level":"warn"' || fail "ingest pipeline does not lowercase the level: $simulated"
api GET _search/pipeline/it_public | grep -q '"visibility":"public"' || fail 'search pipeline missing'
api GET _scripts/it_score | grep -q "params\['factor'\]" || fail 'stored script missing'
rendered=$(api POST _render/template -d '{"id":"it_template","params":{"host":"web1","size":5}}')
echo "$rendered" | grep -q '"host":"web1"' || fail "search template does not render: $rendered"
true
