# OpenVox agent used by the integration tests (scripts/integration-test.sh).
# The real agent package is used instead of the gem, so the tests run with the
# Ruby, Resource API and Facter versions that ship to the nodes.
FROM debian:13-slim
ARG OPENVOX=8
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl \
 && curl -fsSLo /tmp/release.deb "https://apt.voxpupuli.org/openvox${OPENVOX}-release-debian13.deb" \
 && apt-get install -y /tmp/release.deb \
 && apt-get update \
 && apt-get install -y --no-install-recommends openvox-agent \
 && rm -rf /var/lib/apt/lists/* /tmp/release.deb
ENV PATH=/opt/puppetlabs/bin:$PATH
