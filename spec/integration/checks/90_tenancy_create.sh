# Sourced by run.sh after 90_tenancy_create.pp.
# Calls the API with the admin certificate (allow list).
sapi() { curl -sk --cert /certs/admin.pem --key /certs/admin-key.pem "https://localhost:9200/$1"; }
api GET _plugins/_security/api/tenants/it_dev | grep -q '"description":"integration test"' || fail 'tenant it_dev missing'
api GET _plugins/_security/api/tenancy/config | grep -q '"default_tenant":"it_ops"' || fail 'default tenant not set'
if [ "$FACTER_opensearch_major" -ge 3 ]; then
  api GET _plugins/_security/api/tenancy/config | grep -q '"preferred_tenants":\["it_dev","it_ops"\]' || fail 'preferred tenants not set'
fi
sapi _plugins/_security/api/allowlist | grep -q '"requests":{"/_cat/nodes":\["GET"\],"/_cluster/health":\["GET"\]}' || fail 'allow list not set'
# Listing skips the connection "default" (no admin certificate) with a warning.
puppet resource opensearch_allowlist 2>&1 | grep -q "opensearch_allowlist { 'superadmin'" || fail 'puppet resource does not list the allow list'
true
