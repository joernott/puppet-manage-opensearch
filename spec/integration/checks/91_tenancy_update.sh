# Sourced by run.sh after 91_tenancy_update.pp.
code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" https://localhost:9200/_plugins/_security/api/tenants/it_dev)
[ "$code" = 404 ] || fail "tenant it_dev still exists (HTTP $code)"
config=$(api GET _plugins/_security/api/tenancy/config)
echo "$config" | grep -q '"private_tenant_enabled":false' || fail "private tenants not disabled: $config"
echo "$config" | grep -q '"default_tenant":"it_ops"' || fail "default tenant changed: $config"
if [ "$FACTER_opensearch_major" -ge 3 ]; then
  echo "$config" | grep -q '"preferred_tenants":\["it_ops"\]' || fail "preferred tenants not updated: $config"
fi
allowlist=$(sapi _plugins/_security/api/allowlist)
echo "$allowlist" | grep -q '"/_cat/indices":\["GET","HEAD"\]\|"/_cat/indices":\["HEAD","GET"\]' || fail "allow list not updated: $allowlist"
echo "$allowlist" | grep -q '"enabled":false' || fail "allow list enabled changed: $allowlist"
true
