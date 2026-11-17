# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'
require_relative 'config'

module PuppetX
  module ManageOpensearch
    # Raised when the cluster answers with an HTTP error.
    class ApiError < StandardError
      attr_reader :status, :body

      def initialize(method, path, status, body)
        @status = status
        @body = body
        super("#{method} #{path} failed with HTTP #{status}: #{self.class.reason(body)}")
      end

      # Extracts the readable part of an OpenSearch error body.
      def self.reason(body)
        data = JSON.parse(body.to_s)
        return body.to_s unless data.is_a?(Hash)

        error = data['error']
        return [error['type'], error['reason']].compact.join(': ') if error.is_a?(Hash)

        # The security plugin names the offending fields separately.
        details = %w[invalid_keys missing_mandatory_keys].filter_map do |key|
          keys = data.dig(key, 'keys')
          "#{key.tr('_', ' ')}: #{keys}" if keys
        end
        message = (error || data['reason'] || data['message'] || data['status'] || body).to_s
        details.empty? ? message : "#{message} (#{details.join('; ')})"
      rescue JSON::ParserError
        body.to_s.strip
      end
    end

    # Raised when the cluster cannot be reached.
    class ConnectionError < StandardError; end

    # Minimal JSON client for the OpenSearch REST API, based on Net::HTTP only,
    # because the code also runs inside Facter.
    class Client
      RETRY_STATUS = [502, 503, 504].freeze
      RETRY_ERRORS = [
        Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT,
        Net::OpenTimeout, Net::ReadTimeout, EOFError, OpenSSL::SSL::SSLError,
      ].freeze
      METHODS = {
        get: Net::HTTP::Get, put: Net::HTTP::Put, post: Net::HTTP::Post,
        patch: Net::HTTP::Patch, delete: Net::HTTP::Delete,
      }.freeze

      attr_reader :url

      # @return [Client] a client for a connection from the connection file
      def self.for(name = 'default', overrides = {})
        new(Config.connection(name).merge(overrides.transform_keys(&:to_s)))
      end

      # Percent-encodes a value for use as one path segment.
      def self.escape(segment)
        segment.to_s.b.gsub(%r{[^a-zA-Z0-9_.\-~]}) { |c| format('%%%02X', c.ord) }
      end

      # @param settings [Hash] connection settings, see Manage_opensearch::Connection
      def initialize(settings)
        settings = settings.transform_keys(&:to_s)
        @url = settings.fetch('url')
        @uri = URI.parse(@url)
        @base_path = @uri.path.chomp('/')
        @username = settings['username']
        @password = settings['password']
        @ca_file = settings['ca_file']
        @client_cert = settings['client_cert']
        @client_key = settings['client_key']
        @verify_tls = settings.fetch('verify_tls', true)
        @timeout = Integer(settings.fetch('timeout', 30))
        @retries = Integer(settings.fetch('retries', 3))
        @retry_delay = Float(settings.fetch('retry_delay', 2))
      end

      def get(path, params = {})
        request(:get, path, params: params)
      end

      # @return [Object, nil] the parsed response, or nil on 404
      def get_if_exists(path, params = {})
        get(path, params)
      rescue ApiError => e
        raise unless e.status == 404

        nil
      end

      def put(path, body, params = {})
        request(:put, path, body: body, params: params)
      end

      def post(path, body, params = {})
        request(:post, path, body: body, params: params)
      end

      def patch(path, body, params = {})
        request(:patch, path, body: body, params: params)
      end

      def delete(path, params = {})
        request(:delete, path, params: params)
      end

      # @return [String] the OpenSearch version, e.g. "3.9.0"
      def version
        @version ||= get('/').dig('version', 'number')
      end

      # Sends a request, retrying on connection errors and 502/503/504.
      # @return [Object, nil] the parsed JSON response
      def request(method, path, body: nil, params: {})
        attempt = 0
        begin
          response = perform(method, path, body, params)
          status = response.code.to_i
          raise ApiError.new(method.to_s.upcase, path, status, response.body) unless (200..299).cover?(status)

          parse(response.body)
        rescue ApiError, *RETRY_ERRORS => e
          retryable = !e.is_a?(ApiError) || RETRY_STATUS.include?(e.status)
          attempt += 1
          if retryable && attempt <= @retries
            sleep(@retry_delay * (2**(attempt - 1)))
            retry
          end
          raise if e.is_a?(ApiError)

          raise ConnectionError, "#{method.to_s.upcase} #{request_path(path, {})} on #{@uri.host}:#{@uri.port} failed: #{e.class}: #{e.message}"
        end
      end

      private

      def perform(method, path, body, params)
        request = METHODS.fetch(method).new(request_path(path, params))
        request['Accept'] = 'application/json'
        request.basic_auth(@username, @password) if @username
        unless body.nil?
          request['Content-Type'] = 'application/json'
          request.body = JSON.generate(body)
        end
        http.start { |connection| connection.request(request) }
      end

      def request_path(path, params)
        full = "#{@base_path}/#{path.to_s.sub(%r{\A/}, '')}"
        params.empty? ? full : "#{full}?#{URI.encode_www_form(params)}"
      end

      def http
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.open_timeout = @timeout
        http.read_timeout = @timeout
        return http unless @uri.scheme == 'https'

        http.use_ssl = true
        http.verify_mode = @verify_tls ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
        http.ca_file = @ca_file if @ca_file
        if @client_cert
          http.cert = OpenSSL::X509::Certificate.new(File.read(@client_cert))
          http.key = OpenSSL::PKey.read(File.read(@client_key))
        end
        http
      end

      def parse(body)
        return nil if body.nil? || body.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end
    end
  end
end
