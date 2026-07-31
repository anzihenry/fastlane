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

      def app_file_info(app_id)
        request_json(:get, "/publish/v2/app-file-info?appid=#{URI.encode_www_form_component(app_id)}")
      end

      def submit(app_id)
        request_json(:post, "/publish/v2/app-submit?appid=#{URI.encode_www_form_component(app_id)}")
      end

      private

      def request_json(method, path)
        uri = URI.parse("#{@api_base}#{path}")
        request = method == :post ? Net::HTTP::Post.new(uri.request_uri) : Net::HTTP::Get.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@access_token}" unless @access_token.to_s.empty?
        request['client_id'] = @client_id unless @client_id.to_s.empty?
        request['Content-Type'] = 'application/json'
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
    end
  end
end
