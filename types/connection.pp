# @summary Settings of one connection to an OpenSearch cluster
#
# @example
#   {
#     'url'      => 'https://os1.example.com:9200',
#     'username' => 'admin',
#     'password' => Sensitive('secret'),
#     'ca_file'  => '/etc/opensearch/root-ca.pem',
#   }
type Manage_opensearch::Connection = Struct[{
  url                   => Pattern[/\Ahttps?:\/\/\S+\z/],
  Optional[username]    => String[1],
  Optional[password]    => Variant[String[1], Sensitive[String[1]]],
  Optional[ca_file]     => Pattern[/\A\//],
  Optional[client_cert] => Pattern[/\A\//],
  Optional[client_key]  => Pattern[/\A\//],
  Optional[verify_tls]  => Boolean,
  Optional[timeout]     => Integer[1],
  Optional[retries]     => Integer[0],
}]
