#!/bin/sh
# Integration test: applies the manifests in spec/integration/manifests with a
# real OpenVox agent against a single-node OpenSearch container.
#
# Each manifest is applied twice: the first run must change something
# (exit code 2), the second must change nothing (exit code 0). After each
# manifest, spec/integration/checks/<manifest>.sh runs (if present) to verify
# the cluster state through the API.
#
# Usage: scripts/integration-test.sh [opensearch-version] [openvox-major]
# Defaults: 3.9.0 and 8. Requires Docker; uses host port 9200.
set -eu

OPENSEARCH_VERSION=${1:-3.9.0}
OPENVOX=${2:-8}
cd "$(dirname "$0")/.."
MODULE_DIR=$PWD

ADMIN_PASSWORD="Wq9#zR-$(date +%s)-Kx7!"
OS_CONTAINER=manage_opensearch-it-os
AGENT_IMAGE=manage_opensearch-agent:$OPENVOX
export ADMIN_PASSWORD

cleanup() {
  docker rm -f "$OS_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

log() { printf '\n=== %s\n' "$*"; }

log "Building OpenVox $OPENVOX agent image"
docker build -q --build-arg "OPENVOX=$OPENVOX" -t "$AGENT_IMAGE" spec/integration >/dev/null

log "Starting OpenSearch $OPENSEARCH_VERSION"
cleanup
docker run -d --name "$OS_CONTAINER" -p 9200:9200 \
  -e discovery.type=single-node \
  -e cluster.routing.allocation.disk.threshold_enabled=false \
  -e OPENSEARCH_JAVA_OPTS='-Xms512m -Xmx512m' \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=$ADMIN_PASSWORD" \
  "opensearchproject/opensearch:$OPENSEARCH_VERSION" >/dev/null

i=0
until [ "$(curl -sk -o /dev/null -w '%{http_code}' -u "admin:$ADMIN_PASSWORD" https://localhost:9200/_cluster/health)" = 200 ]; do
  i=$((i + 1))
  if [ "$i" -gt 90 ]; then
    docker logs --tail 50 "$OS_CONTAINER"
    echo "OpenSearch did not become ready" >&2
    exit 1
  fi
  sleep 2
done
echo "ready"

log "Running manifests"
docker run --rm --network host \
  -e ADMIN_PASSWORD \
  -e "FACTER_opensearch_admin_password=$ADMIN_PASSWORD" \
  -v "$MODULE_DIR:/etc/puppetlabs/code/environments/production/modules/manage_opensearch:ro" \
  "$AGENT_IMAGE" sh /etc/puppetlabs/code/environments/production/modules/manage_opensearch/spec/integration/run.sh

log "Integration test passed (OpenSearch $OPENSEARCH_VERSION, OpenVox $OPENVOX)"
