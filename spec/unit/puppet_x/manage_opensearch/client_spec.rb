# frozen_string_literal: true

require 'spec_helper'
require 'puppet_x/manage_opensearch/client'

describe PuppetX::ManageOpensearch::Client do
  subject(:client) { described_class.new('url' => 'https://os.example.com:9200', 'username' => 'admin', 'password' => 'pw', 'retries' => 2, 'retry_delay' => 0) }

  it 'sends authenticated JSON requests and parses the response' do
    stub = stub_request(:put, 'https://os.example.com:9200/_index_template/t1')
           .with(basic_auth: %w[admin pw], body: { 'priority' => 1 }, headers: { 'Content-Type' => 'application/json' })
           .to_return(json('acknowledged' => true))
    expect(client.put('_index_template/t1', 'priority' => 1)).to eq('acknowledged' => true)
    expect(stub).to have_been_requested
  end

  it 'adds query parameters' do
    stub_request(:get, 'https://os.example.com:9200/_nodes?filter_path=nodes.*.name').to_return(json('nodes' => {}))
    expect(client.get('_nodes', 'filter_path' => 'nodes.*.name')).to eq('nodes' => {})
  end

  it 'keeps a path prefix of the URL' do
    prefixed = described_class.new('url' => 'https://proxy.example.com/opensearch/')
    stub_request(:get, 'https://proxy.example.com/opensearch/_cluster/health').to_return(json('status' => 'green'))
    expect(prefixed.get('/_cluster/health')).to eq('status' => 'green')
  end

  it 'raises ApiError with the reason of an OpenSearch error' do
    stub_request(:get, 'https://os.example.com:9200/x').to_return(
      status: 400, body: JSON.generate('error' => { 'type' => 'illegal_argument_exception', 'reason' => 'bad' }, 'status' => 400),
    )
    expect { client.get('x') }.to raise_error(PuppetX::ManageOpensearch::ApiError, %r{HTTP 400: illegal_argument_exception: bad}) { |e| expect(e.status).to eq(400) }
  end

  it 'raises ApiError with the message of a security plugin error' do
    stub_request(:put, 'https://os.example.com:9200/r').to_return(status: 403, body: '{"status":"FORBIDDEN","message":"Resource is reserved."}')
    expect { client.put('r', {}) }.to raise_error(PuppetX::ManageOpensearch::ApiError, %r{Resource is reserved})
  end

  it 'raises ApiError with the reason of a security plugin validation error' do
    stub_request(:put, 'https://os.example.com:9200/u').to_return(status: 400, body: '{"status":"error","reason":"Weak password"}')
    expect { client.put('u', {}) }.to raise_error(PuppetX::ManageOpensearch::ApiError, %r{HTTP 400: Weak password})
  end

  it 'returns nil from get_if_exists on 404' do
    stub_request(:get, 'https://os.example.com:9200/missing').to_return(status: 404, body: '{}')
    expect(client.get_if_exists('missing')).to be_nil
  end

  it 'retries on 503' do
    stub_request(:get, 'https://os.example.com:9200/')
      .to_return({ status: 503, body: 'OpenSearch Security not initialized.' }, json('version' => { 'number' => '3.9.0' }))
    expect(client.version).to eq('3.9.0')
  end

  it 'does not retry other errors' do
    stub = stub_request(:delete, 'https://os.example.com:9200/x').to_return(status: 500, body: 'boom')
    expect { client.delete('x') }.to raise_error(PuppetX::ManageOpensearch::ApiError)
    expect(stub).to have_been_requested.once
  end

  it 'raises ConnectionError after the retries are used up' do
    stub = stub_request(:get, 'https://os.example.com:9200/x').to_raise(Errno::ECONNREFUSED)
    expect { client.get('x') }.to raise_error(PuppetX::ManageOpensearch::ConnectionError, %r{GET /x on os.example.com:9200 failed})
    expect(stub).to have_been_requested.times(3)
  end

  it 'escapes path segments' do
    expect(described_class.escape('a b/ä')).to eq('a%20b%2F%C3%A4')
  end

  describe '.for' do
    it 'reads the connection from the connection file' do
      use_connections('other' => { 'url' => 'http://other:9200' })
      expect(described_class.for('other').url).to eq('http://other:9200')
    end

    it 'fails for an unknown connection' do
      use_connections
      expect { described_class.for('nope') }.to raise_error(PuppetX::ManageOpensearch::ConfigError, %r{connection 'nope' is not defined})
    end
  end
end
