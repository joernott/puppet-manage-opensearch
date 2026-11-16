# Sourced by run.sh after 10_security_create.pp.
api GET _plugins/_security/api/roles/it_logs_reader | grep -q '"masked_fields":\["ip"\]' || fail 'role it_logs_reader not as expected'
api GET _plugins/_security/api/rolesmapping/it_logs_reader | grep -q 'ldap-auditors' || fail 'role mapping missing'
api GET _plugins/_security/api/actiongroups/it_logs_read | grep -q 'indices:admin/mappings/get' || fail 'action group missing'
# The initial password works
[ "$(curl -sk -o /dev/null -w '%{http_code}' -u 'it_alice:Initial-Pw-2026!' https://localhost:9200/_plugins/_security/authinfo)" = 200 ] ||
  fail 'it_alice cannot log in with the initial password'
# Change the password outside Puppet; Puppet must not reset it (decision 3)
api PUT _plugins/_security/api/internalusers/it_alice -d '{"password":"Changed-Pw-2026!","backend_roles":["ldap-readers"],"opendistro_security_roles":["it_logs_reader"],"attributes":{"team":"ops","level":"3"},"description":"integration test"}' >/dev/null
puppet resource opensearch_role it_logs_reader
true
