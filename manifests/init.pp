# @summary Writes the connection settings used by the opensearch_* types and facts
#
# Include this class on every OpenSearch node that should report the
# `opensearch` fact or manage `opensearch_*` resources. It writes the
# connection settings to `/etc/puppetlabs/manage_opensearch/connections.yaml`
# (owner root, mode 0600). The top-level parameters describe the connection
# named `default`. `connections` adds more named connections, which resources
# select with their `connection` parameter.
#
# @example Connect to the local node with basic auth
#   class { 'manage_opensearch':
#     username => 'admin',
#     password => Sensitive('secret'),
#     ca_file  => '/etc/opensearch/root-ca.pem',
#   }
#
# @param url
#   URL of the default connection. Defaults to the local node, so the facts
#   describe the node Puppet runs on.
# @param username
#   User for basic authentication.
# @param password
#   Password for basic authentication.
# @param ca_file
#   CA certificate (PEM) used to verify the cluster's TLS certificate.
# @param client_cert
#   Client certificate (PEM) for certificate authentication, e.g. the admin
#   certificate.
# @param client_key
#   Private key (PEM) belonging to `client_cert`.
# @param verify_tls
#   Whether to verify the cluster's TLS certificate. Only disable this in labs.
# @param timeout
#   HTTP timeout in seconds.
# @param retries
#   How often a request is retried when the cluster is unreachable or answers
#   with 503.
# @param connections
#   Additional named connections. The name `default` is reserved for the
#   connection described by the top-level parameters.
class manage_opensearch (
  Pattern[/\Ahttps?:\/\/\S+\z/] $url = "https://${facts['networking']['fqdn']}:9200",
  Optional[String[1]] $username = undef,
  Optional[Variant[String[1], Sensitive[String[1]]]] $password = undef,
  Optional[Pattern[/\A\//]] $ca_file = undef,
  Optional[Pattern[/\A\//]] $client_cert = undef,
  Optional[Pattern[/\A\//]] $client_key = undef,
  Boolean $verify_tls = true,
  Integer[1] $timeout = 30,
  Integer[0] $retries = 3,
  Hash[Pattern[/\A[a-z0-9_]+\z/], Manage_opensearch::Connection] $connections = {},
) {
  if 'default' in $connections {
    fail('manage_opensearch: use the top-level parameters for the connection "default", not $connections')
  }

  $default_connection = {
    'url'         => $url,
    'username'    => $username,
    'password'    => $password,
    'ca_file'     => $ca_file,
    'client_cert' => $client_cert,
    'client_key'  => $client_key,
    'verify_tls'  => $verify_tls,
    'timeout'     => $timeout,
    'retries'     => $retries,
  }

  # Drop unset values and unwrap passwords. The file content stays Sensitive.
  $all = ({ 'default' => $default_connection } + $connections).reduce({}) |$memo, $entry| {
    $settings = $entry[1].filter |$k, $v| { $v =~ NotUndef }.map |$k, $v| {
      $value = if $v =~ Sensitive { $v.unwrap } else { $v }
      [$k, $value]
    }
    $memo + { $entry[0] => Hash($settings) }
  }

  file { '/etc/puppetlabs/manage_opensearch':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  file { '/etc/puppetlabs/manage_opensearch/connections.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => Sensitive(manage_opensearch::to_yaml({ 'connections' => $all })),
  }
}
