require 'json'
require 'net/http'
require 'uri'

module Fastlane
  module Helper
    class AppgalleryClient
      DEFAULT_API_BASE = 'https://connect-api.cloud.huawei.com'.freeze

      def initialize(api_base: DEFAULT_API_BASE, access_token: nil, client_id: nil)
        @api_base = api_base.chomp('/')
        @access_token = access_token
        @client_id = client_id
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
        request['Authorization'] = "Bearer #{@access_token}" unless @access_token.to_s.empty?
        request['client_id'] = @client_id unless @client_id.to_s.empty?
        request['Content-Type'] = 'application/json'
        request.body = JSON.generate(body) if body
        response = perform(uri, request)
        JSON.parse(response.body)
      rescue JSON::ParserError
        { 'raw_body' => response.body }
      end

      def perform(uri, request)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(request) }
        return response if response.is_a?(Net::HTTPSuccess)

        UI.user_error!("AppGallery Connect request failed (#{response.code}): #{response.body}")
      end

      def find_value(object, key)
        return object[key] if object.is_a?(Hash) && object.key?(key)
        return object.values.lazy.map { |value| find_value(value, key) }.find(&:itself) if object.is_a?(Hash)

        nil
      end
    end
  end
end
