class { 'manage_opensearch':
  url         => 'https://localhost:9200',
  username    => 'admin',
  password    => Sensitive($facts['opensearch_admin_password']),
  verify_tls  => false,
  connections => {
    'superadmin' => {
      'url'         => 'https://localhost:9200',
      'client_cert' => '/certs/admin.pem',
      'client_key'  => '/certs/admin-key.pem',
      'verify_tls'  => false,
    },
  },
}
