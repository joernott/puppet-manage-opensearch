# Sourced by run.sh after 00_setup.pp: the opensearch fact is now available.
facts=$(facter --json --custom-dir "$MODULE/lib/facter" opensearch)
echo "opensearch fact: $(printf '%s' "$facts" | wc -c) bytes"
for expected in '"cluster_name": "docker-cluster"' '"status": "' '"cluster_manager"' '"nodes": \[' '"transport_address"'; do
  echo "$facts" | grep -q "$expected" || fail "opensearch fact lacks $expected"
done
echo "$facts" | grep -qi 'password' && fail 'opensearch fact contains a password key'
true
