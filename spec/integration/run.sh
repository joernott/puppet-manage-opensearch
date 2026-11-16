#!/bin/sh
# Runs inside the agent container, see scripts/integration-test.sh.
set -eu

MODULE=/etc/puppetlabs/code/environments/production/modules/manage_opensearch
DIR=$MODULE/spec/integration
export MODULE

# Calls the API as admin; used by the checks.
api() {
  method=$1
  path=$2
  shift 2
  curl -sk -X "$method" -u "admin:$ADMIN_PASSWORD" -H 'Content-Type: application/json' \
    "https://localhost:9200/$path" "$@"
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for source in "$DIR"/manifests/*.pp; do
  name=$(basename "$source" .pp)
  # Every manifest declares the class with the same parameters (common.pp).
  manifest=/tmp/$name.pp
  cat "$DIR/common.pp" "$source" > "$manifest"
  echo
  echo "--- $name: first run (expect changes)"
  set +e
  puppet apply --detailed-exitcodes --color=false "$manifest"
  code=$?
  set -e
  [ "$code" -eq 2 ] || fail "$name: first run exited with $code, expected 2"

  echo "--- $name: second run (expect no changes)"
  set +e
  puppet apply --detailed-exitcodes --color=false "$manifest"
  code=$?
  set -e
  [ "$code" -eq 0 ] || fail "$name: second run exited with $code, expected 0 (not idempotent)"

  if [ -f "$DIR/checks/$name.sh" ]; then
    echo "--- $name: checks"
    . "$DIR/checks/$name.sh"
  fi
done

echo
echo "All manifests converged and are idempotent."
