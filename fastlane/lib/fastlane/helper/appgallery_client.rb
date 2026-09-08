require 'json'
require 'net/http'
require 'uri'

module Fastlane
  module Helper
    class AppgalleryClient
      DEFAULT_API_BASE = 'https://connect-api.cloud.huawei.com/api'.freeze

      def initialize(api_base: DEFAULT_API_BASE, access_token: nil, client_id: nil, client_secret: nil)
        @api_base = api_base.chomp('/')
        @access_token = access_token
        @client_id = client_id
        @client_secret = client_secret
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

      def update_app_info(app_id, app_info)
        request_json(:put, "/publish/v2/app-info?appId=#{URI.encode_www_form_component(app_id)}", body: app_info)
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

      def submit(app_id)
        request_json(:post, "/publish/v2/app-submit?appid=#{URI.encode_www_form_component(app_id)}")
      end

      private

      def request_json(method, path, body: nil)
        uri = URI.parse("#{@api_base}#{path}")
        request = case method
                  when :post then Net::HTTP::Post.new(uri.request_uri)
                  when :put then Net::HTTP::Put.new(uri.request_uri)
                  else Net::HTTP::Get.new(uri.request_uri)
                  end
        request['Authorization'] = "Bearer #{access_token}"
        request['client_id'] = required_client_id
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body) if body
        response = perform(uri, request)
        JSON.parse(response.body)
      rescue JSON::ParserError
        { 'raw_body' => response.body }
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
