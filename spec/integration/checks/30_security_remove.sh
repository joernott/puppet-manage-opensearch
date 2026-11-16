# Sourced by run.sh after 30_security_remove.pp.
for path in roles/it_logs_reader rolesmapping/it_logs_reader actiongroups/it_logs_read internalusers/it_alice internalusers/it_bob; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" "https://localhost:9200/_plugins/_security/api/$path")
  [ "$code" = 404 ] || fail "$path still exists (HTTP $code)"
done
