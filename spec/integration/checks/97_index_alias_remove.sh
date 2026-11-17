# Sourced by run.sh after 97_index_alias_remove.pp.
for path in it-orders-1 it-orders-2 it-orders-3 _alias/it-orders _alias/it-orders-eu; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" "https://localhost:9200/$path")
  [ "$code" = 404 ] || fail "$path still exists (HTTP $code)"
done
true
