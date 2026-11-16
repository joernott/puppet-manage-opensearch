# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

describe 'manage_opensearch' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:config_file) { '/etc/puppetlabs/manage_opensearch/connections.yaml' }
      let(:written_config) do
        content = catalogue.resource('File', config_file)[:content]
        content = content.unwrap if content.respond_to?(:unwrap)
        YAML.safe_load(content)
      end

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/puppetlabs/manage_opensearch').with(ensure: 'directory', mode: '0700') }
        it { is_expected.to contain_file(config_file).with(ensure: 'file', owner: 'root', mode: '0600') }

        it 'points the default connection at the local node' do
          expect(written_config['connections']['default']).to eq(
            'url' => "https://#{facts[:networking]['fqdn']}:9200",
            'verify_tls' => true, 'timeout' => 30, 'retries' => 3
          )
        end
      end

      context 'with credentials and extra connections' do
        let(:params) do
          {
            username: 'admin',
            password: sensitive('s3cret'),
            ca_file: '/etc/opensearch/root-ca.pem',
            connections: { 'other' => { 'url' => 'https://other:9200', 'password' => sensitive('pw2') } },
          }
        end

        it 'writes unwrapped passwords for all connections' do
          conns = written_config['connections']
          expect(conns['default']).to include('username' => 'admin', 'password' => 's3cret', 'ca_file' => '/etc/opensearch/root-ca.pem')
          expect(conns['other']).to eq('url' => 'https://other:9200', 'password' => 'pw2')
        end
      end

      context 'with a connection named default' do
        let(:params) { { connections: { 'default' => { 'url' => 'https://x:9200' } } } }

        it { is_expected.to compile.and_raise_error(%r{top-level parameters}) }
      end
    end
  end
end
