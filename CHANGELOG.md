# Changelog

## 0.2.0 (2026-11-17)

* New types `opensearch_index` (single indices: settings, mappings, open or
  closed) and `opensearch_alias` (atomic alias changes).
* New types `opensearch_ingest_pipeline`, `opensearch_search_pipeline` and
  `opensearch_stored_script` (scripts and search templates).
* New types `opensearch_tenant`, `opensearch_tenancy_config` and
  `opensearch_allowlist` (needs a connection with the admin certificate).
* Error messages of the security API name the rejected fields.

## 0.1.0 (2026-11-16)

First version.

* Class `manage_opensearch` writes the connection settings (basic auth or
  client certificate, several named connections).
* Types `opensearch_role`, `opensearch_role_mapping`, `opensearch_action_group`,
  `opensearch_internal_user`, `opensearch_index_template`,
  `opensearch_ism_policy` and `opensearch_data_stream`.
* Structured fact `opensearch` with cluster health, a brief cluster state, the
  node names and the info of the local node (plugins and modules only with
  name and version).
* Tested with OpenSearch 2.19 and 3.9 and OpenVox 8 and 9.
