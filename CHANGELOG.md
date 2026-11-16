# Changelog

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
