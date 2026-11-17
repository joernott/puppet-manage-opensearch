# Sourced by run.sh after 96_index_alias_update.pp.
api GET '_cat/indices/it-orders-1?h=status' | grep -q close || fail 'it-orders-1 not closed'
api GET 'it-orders-1/_settings?expand_wildcards=all' | grep -q '"codec":"best_compression"' || fail 'codec of it-orders-1 not changed'
api GET it-orders-2/_settings | grep -q '"refresh_interval":"10s"' || fail 'refresh interval of it-orders-2 not changed'
api GET it-orders-2/_mapping | grep -q '"amount":{"type":"float"}' || fail 'mapping field amount not added'
written=$(api POST 'it-orders/_doc' -d '{"id":"2","region":"de"}')
echo "$written" | grep -q '"_index":"it-orders-3"' || fail "alias it-orders does not write to it-orders-3: $written"
eu=$(api GET _alias/it-orders-eu)
echo "$eu" | grep -q 'it-orders-1' && fail "alias it-orders-eu still on it-orders-1: $eu"
echo "$eu" | grep -q '"it-orders-3":{"aliases":{"it-orders-eu":{"filter":{"term":{"region":"eu"}}}}}' || fail "new index did not get the filter: $eu"
true
