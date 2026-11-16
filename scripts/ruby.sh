#!/bin/sh
# Runs a command in a Ruby container with the module mounted at /module.
# The command runs as the calling user; gems are cached per Ruby version in a
# Docker volume.
#   RUBY_VERSION         Ruby image tag (default 3.2, as shipped with OpenVox 8)
#   OPENVOX_GEM_VERSION  passed to the Gemfile, e.g. '~> 9.0'
# Example: scripts/ruby.sh bundle exec rake test
set -eu
RUBY_VERSION=${RUBY_VERSION:-3.2}
cd "$(dirname "$0")/.."
image="ruby:$RUBY_VERSION"
volume="manage_opensearch-gems-$RUBY_VERSION"
uid=$(id -u)
gid=$(id -g)

# Give the gem cache to the calling user (only changes anything on first use).
docker run --rm -v "$volume:/usr/local/bundle" "$image" \
  sh -c "[ \"\$(stat -c %u /usr/local/bundle)\" = $uid ] || chown -R $uid:$gid /usr/local/bundle"

tty=
if [ -t 1 ]; then tty=-t; fi
exec docker run --rm $tty --network host -u "$uid:$gid" -e HOME=/tmp \
  -v "$PWD:/module" -w /module \
  -v "$volume:/usr/local/bundle" \
  -e OPENVOX_GEM_VERSION \
  -e MANAGE_OPENSEARCH_CONFIG \
  "$image" "$@"
