# Sourced by run.sh after 40_templates_ism_create.pp.
api GET _index_template/it_logs | grep -q '"refresh_interval":"5s"' || fail 'template it_logs not as expected'
api GET _index_template/it_stream | grep -q '"timestamp_field"' || fail 'template it_stream is no data stream template'
api GET _plugins/_ism/policies/it_retention | grep -q '"min_index_age":"30d"' || fail 'ISM policy missing'
# Template and policy apply to new indices
api PUT it-logs-000001 >/dev/null
api GET it-logs-000001/_settings | grep -q '"refresh_interval":"5s"' || fail 'template not applied to new index'
puppet resource opensearch_ism_policy it_retention
true
