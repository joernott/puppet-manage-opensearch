# Sourced by run.sh after 20_security_update.pp.
role=$(api GET _plugins/_security/api/roles/it_logs_reader)
echo "$role"
echo "$role" | grep -q 'cluster_composite_ops_ro' || fail 'unmanaged cluster_permissions were changed'
echo "$role" | grep -q 'metrics-' && fail 'index_permissions were not replaced'
user=$(api GET _plugins/_security/api/internalusers/it_alice)
echo "$user"
echo "$user" | grep -q 'ldap-writers' || fail 'backend_roles of it_alice not updated'
echo "$user" | grep -q '"team":"ops"' || fail 'unmanaged attributes of it_alice were changed'
[ "$(curl -sk -o /dev/null -w '%{http_code}' -u 'it_alice:Changed-Pw-2026!' https://localhost:9200/_plugins/_security/authinfo)" = 200 ] ||
  fail 'the password of it_alice was changed by Puppet'
api GET _plugins/_security/api/rolesmapping/it_logs_reader | grep -q 'ldap-auditors' || fail 'unmanaged backend_roles of the mapping were changed'
true
