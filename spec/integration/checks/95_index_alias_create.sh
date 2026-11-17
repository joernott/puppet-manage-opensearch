# Sourced by run.sh after 95_index_alias_create.pp.
api GET it-orders-1/_mapping | grep -q '"dynamic":"strict"' || fail 'mappings of it-orders-1 not set'
api GET it-orders-2/_settings | grep -q '"refresh_interval":"5s"' || fail 'settings of it-orders-2 not set'
written=$(api POST 'it-orders/_doc?refresh=true' -d '{"id":"1","region":"eu"}')
echo "$written" | grep -q '"_index":"it-orders-2"' || fail "alias it-orders does not write to it-orders-2: $written"
eu=$(api GET _alias/it-orders-eu)
echo "$eu" | grep -q '"it-orders-1":{"aliases":{"it-orders-eu":{"filter"' || fail "filtered alias missing on it-orders-1: $eu"
listed=$(puppet resource opensearch_index)
echo "$listed" | grep -q "opensearch_index { 'default/it-orders-1'" || fail 'puppet resource does not list the index'
echo "$listed" | grep -q "opensearch_index { 'default/\." && fail 'puppet resource lists an index starting with a dot'
true
