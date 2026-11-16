class { 'manage_opensearch':
  url        => 'https://localhost:9200',
  username   => 'admin',
  password   => Sensitive($facts['opensearch_admin_password']),
  verify_tls => false,
}
