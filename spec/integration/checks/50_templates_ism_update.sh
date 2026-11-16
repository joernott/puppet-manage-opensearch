# Sourced by run.sh after 50_templates_ism_update.pp.
template=$(api GET _index_template/it_logs)
echo "$template"
echo "$template" | grep -q '"number_of_shards":"2"' || fail 'template setting not updated'
echo "$template" | grep -q '"priority":20' || fail 'template priority not updated'
echo "$template" | grep -q '"owner":"ops"' || fail 'unmanaged _meta of the template was changed'
echo "$template" | grep -q '"version":3' || fail 'unmanaged version of the template was changed'
policy=$(api GET _plugins/_ism/policies/it_retention)
echo "$policy"
echo "$policy" | grep -q '"min_index_age":"60d"' || fail 'ISM policy not updated'
echo "$policy" | grep -q '"description":"integration test"' || fail 'unmanaged description of the policy was changed'
echo "$policy" | grep -q '"it-logs-\*"' || fail 'unmanaged ism_template of the policy was changed'
true
