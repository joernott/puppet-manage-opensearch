# Sourced by run.sh after 93_pipelines_scripts_update.pp.
pipeline=$(api GET _ingest/pipeline/it_enrich)
echo "$pipeline" | grep -q '"version":2' || fail "ingest pipeline version not updated: $pipeline"
echo "$pipeline" | grep -q '"description":"integration test"' || fail "unmanaged description changed: $pipeline"
echo "$pipeline" | grep -q '"on_failure"' || fail "unmanaged on_failure lost: $pipeline"
search=$(api GET _search/pipeline/it_public)
echo "$search" | grep -q '"description":"public documents only"' || fail "search pipeline not updated: $search"
echo "$search" | grep -q '"visibility":"public"' || fail "unmanaged request processors lost: $search"
api GET _scripts/it_score | grep -q '\* 2' || fail 'stored script not updated'
api GET _scripts/it_score | grep -q '"lang":"painless"' || fail 'stored script lost its language'
true
