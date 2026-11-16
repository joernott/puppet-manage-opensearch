# puppet-manage_opensearch
There are a couple of puppet modules that handle the installation of opensearch or elasticsearch but I found none that configures an existing opensearch cluster using the REST api. This puppet module aims to close the gap.

It supports opensearch 2 and opensearch 3 and openvox 8 and newer (puppet 8 / 9). It follows a similar approach as the now archived (puppet-rest_api_resource module)[https://github.com/JCotton1123/puppet-rest_api_resource], but instead of implementing the API as singular functions, I would like to create custom resources:

The initial version 0.1.0 supports the following custom resources:
- opensearch_role: Creating, modifying and deleting roles (https://docs.opensearch.org/latest/security/api/roles/index/)
- opensearch_action_group: Managing action groups (https://docs.opensearch.org/latest/security/api/action-groups/index/)
- opensearch_internal_user: Creating, modifying and deleting users, creating tokens for users (https://docs.opensearch.org/latest/security/api/users/index/)
- opensearch_role_mapping: Managing role mappings (https://docs.opensearch.org/latest/security/api/role-mappings/index/)
- opensearch_index_template: Managing Index templates (https://docs.opensearch.org/latest/im-plugin/index-templates/)
- opensearch_ism_policy: Managing index state management policies (https://docs.opensearch.org/latest/im-plugin/ism/api/)

The initial version 0.1.0 should contain custom facts that will be available on hosts that include the manage_opensearch class. The tree should look like this  (including the API endpoint data as comment in this document, not in the real fact):
```yaml
opensearch:
  cluster:
    health: {} # The data returned by GET /_cluster/health, see https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-health/
    state: {} # The data returned by GET /_cluster/state
    nodes: {} # The array of node names, you get from GET /_nodes (https://docs.opensearch.org/latest/api-reference/nodes-apis/nodes-info/)
    node: {} # The data you get from GET/_nodes/{node_id} for the host, puppet runs on
```
