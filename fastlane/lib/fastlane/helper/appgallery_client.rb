require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module Fastlane
  module Helper
    class AppgalleryClient
      DEFAULT_API_BASE = 'https://connect-api.cloud.huawei.com/api'.freeze
      DEFAULT_SERVICE_ACCOUNT_AUDIENCE = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token'.freeze

      def initialize(api_base: DEFAULT_API_BASE, access_token: nil, client_id: nil, client_secret: nil, service_account_key_path: nil)
        @api_base = api_base.chomp('/')
        @access_token = access_token
        @client_id = client_id
        @client_secret = client_secret
        @service_account_key_path = service_account_key_path
        @token_expires_at = nil
      end

      def upload_file(upload_url, file_path)
        uri = URI.parse(upload_url)
        request = Net::HTTP::Put.new(uri.request_uri)
        request['Content-Type'] = 'application/octet-stream'
        request['Content-Length'] = File.size(file_path).to_s
        request.body = File.binread(file_path)
        perform(uri, request)
      end

      def upload_url(app_id, suffix)
        response = request_json(:get, "/publish/v2/upload-url?appId=#{URI.encode_www_form_component(app_id)}&suffix=#{URI.encode_www_form_component(suffix)}")
        find_value(response, 'uploadUrl') || UI.user_error!('AppGallery Connect did not return an upload URL')
      end

      def update_app_file_info(app_id, file_info)
        request_json(:put, "/publish/v2/app-file-info?appid=#{URI.encode_www_form_component(app_id)}", body: file_info)
      end

      def app_file_info(app_id)
        request_json(:get, "/publish/v2/app-file-info?appid=#{URI.encode_www_form_component(app_id)}")
      end

      def app_info(app_id, lang: nil, release_type: nil)
        query = { 'appId' => app_id, 'lang' => lang, 'releaseType' => release_type }.compact
        request_json(:get, "/publish/v2/app-info?#{URI.encode_www_form(query)}")
      end

      def app_ids(package_names, package_types: nil)
        query = { 'packageName' => package_names.join(','), 'packageTypes' => package_types&.join(',') }.compact
        request_json(:get, "/publish/v2/appid-list?#{URI.encode_www_form(query)}")
      end

      def versions(app_id, package_name: nil, state: nil)
        body = { 'packageName' => package_name, 'state' => state.nil? ? nil : Array(state).join(',') }.compact
        request_json(:post, '/publish/v3/version/brief-info/list', body: body, headers: { 'appId' => app_id })
      end

      def package_compile_status(app_id, package_ids)
        query = { 'appId' => app_id, 'pkgIds' => Array(package_ids).join(',') }
        request_json(:get, "/publish/v3/package/compile/status?#{URI.encode_www_form(query)}")
      end

      def update_app_info(app_id, app_info)
        request_json(:put, "/publish/v3/app-info?appId=#{URI.encode_www_form_component(app_id)}", body: app_info)
      end

      def update_language_info(app_id, language_info, release_type: nil, release_phase: nil)
        query = { 'appId' => app_id, 'releaseType' => release_type, 'releasePhase' => release_phase }.compact
        request_json(:put, "/publish/v3/app-language-info?#{URI.encode_www_form(query)}", body: language_info)
      end

      def delete_language_info(app_id, lang, release_type: nil)
        query = { 'appId' => app_id, 'lang' => lang, 'releaseType' => release_type }.compact
        request_json(:delete, "/publish/v2/app-language-info?#{URI.encode_www_form(query)}")
      end

      def download_file(download_url, output_path)
        uri = URI.parse(download_url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(Net::HTTP::Get.new(uri.request_uri))
        end
        UI.user_error!("AppGallery package download failed (#{response.code}): #{response.body}") unless response.kind_of?(Net::HTTPSuccess)

        File.binwrite(output_path, response.body)
        output_path
      end

      def submit(app_id, release_info: {})
        request_json(:post, "/publish/v3/app-submit?appId=#{URI.encode_www_form_component(app_id)}", body: release_info)
      end

      def update_phased_release(app_id, version_id:, release_phase: nil, state: nil, description: nil, phase_day: nil)
        body = {
          'versionId' => version_id,
          'releasePhase' => release_phase,
          'state' => state,
          'description' => description,
          'phaseDay' => phase_day
        }.compact
        request_json(:put, '/publish/v2/version/phased-release', body: body, headers: { 'appId' => app_id })
      end

      def cancel_review(app_id, version_id)
        request_json(:put, '/publish/v3/version/on-shelf/cancel', body: { 'versionId' => version_id }, headers: { 'appId' => app_id })
      end

      private

      def request_json(method, path, body: nil, headers: {})
        uri = URI.parse("#{@api_base}#{path}")
        request = case method
                  when :post then Net::HTTP::Post.new(uri.request_uri)
                  when :put then Net::HTTP::Put.new(uri.request_uri)
                  when :delete then Net::HTTP::Delete.new(uri.request_uri)
                  else Net::HTTP::Get.new(uri.request_uri)
                  end
        authentication_headers.each { |key, value| request[key] = value }
        headers.each { |key, value| request[key] = value }
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body) if body
        response = perform(uri, request)
        JSON.parse(response.body)
      rescue JSON::ParserError
        { 'raw_body' => response.body }
      end

      def authentication_headers
        if @service_account_key_path.to_s.empty?
          { 'Authorization' => "Bearer #{access_token}", 'client_id' => required_client_id }
        else
          { 'Authorization' => "Bearer #{service_account_token}" }
        end
      end

      def service_account_token
        return @access_token unless @access_token.to_s.empty? || token_expired?

        credentials = service_account_credentials
        issued_at = Time.now.to_i
        expires_at = issued_at + 3600
        header = { kid: required_credential(credentials, 'key_id'), typ: 'JWT', alg: 'PS256' }
        payload = {
          aud: credentials['token_uri'].to_s.empty? ? DEFAULT_SERVICE_ACCOUNT_AUDIENCE : credentials['token_uri'],
          iss: required_credential(credentials, 'sub_account'),
          exp: expires_at,
          iat: issued_at
        }
        signing_input = [header, payload].map { |part| base64url(JSON.generate(part)) }.join('.')
        private_key = OpenSSL::PKey.read(required_credential(credentials, 'private_key'))
        signature = private_key.sign_pss('SHA256', signing_input, salt_length: :digest, mgf1_hash: 'SHA256')
        @access_token = "#{signing_input}.#{base64url(signature)}"
        @token_expires_at = Time.at(expires_at - 60)
        @access_token
      rescue Errno::ENOENT, JSON::ParserError, OpenSSL::PKey::PKeyError
        UI.user_error!('Unable to read the AppGallery Connect service account credential file')
      end

      def service_account_credentials
        JSON.parse(File.read(File.expand_path(@service_account_key_path)))
      end

      def required_credential(credentials, key)
        value = credentials[key]
        UI.user_error!("AppGallery Connect service account credential is missing #{key}") if value.to_s.empty?

        value
      end

      def base64url(value)
        Base64.urlsafe_encode64(value, padding: false)
      end

      def access_token
        return @access_token unless @access_token.to_s.empty? || token_expired?

        UI.user_error!('No AppGallery Connect client secret provided') if @client_secret.to_s.empty?

        uri = URI.parse("#{@api_base}/oauth2/v1/token")
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(
          grant_type: 'client_credentials',
          client_id: required_client_id,
          client_secret: @client_secret
        )
        response = perform(uri, request)
        payload = JSON.parse(response.body)
        @access_token = payload['access_token']
        UI.user_error!('AppGallery Connect did not return an access token') if @access_token.to_s.empty?

        expires_in = payload['expires_in'].to_i
        refresh_after = expires_in > 60 ? expires_in - 60 : expires_in
        @token_expires_at = Time.now + refresh_after if expires_in.positive?
        @access_token
      rescue JSON::ParserError
        UI.user_error!('AppGallery Connect returned an invalid token response')
      end

      def required_client_id
        UI.user_error!('No AppGallery Connect client ID provided') if @client_id.to_s.empty?

        @client_id
      end

      def token_expired?
        @token_expires_at && Time.now >= @token_expires_at
      end

      def perform(uri, request)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(request) }
        return response if response.kind_of?(Net::HTTPSuccess)

        UI.user_error!("AppGallery Connect request failed (#{response.code}): #{response.body}")
      end

      def find_value(object, key)
        return object[key] if object.kind_of?(Hash) && object.key?(key)
        return object.values.lazy.map { |value| find_value(value, key) }.find(&:itself) if object.kind_of?(Hash)

        nil
      end
    end
  end
end
