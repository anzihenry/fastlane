require 'fastlane/helper/appgallery_client'

module Fastlane
  module Actions
    class GetAppgalleryVersionAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id])
        client.app_file_info(params[:app_id])
      end

      def self.description
        'Fetch AppGallery Connect package information for a HarmonyOS app'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app_id, env_name: 'FL_APPGALLERY_APP_ID', description: 'AppGallery Connect application ID', verify_block: proc { |value| UI.user_error!('No AppGallery application ID provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :api_base, env_name: 'FL_APPGALLERY_API_BASE', description: 'AppGallery Connect API base URL', default_value: Helper::AppgalleryClient::DEFAULT_API_BASE),
          FastlaneCore::ConfigItem.new(key: :access_token, env_name: 'FL_APPGALLERY_ACCESS_TOKEN', description: 'AppGallery Connect API access token', sensitive: true),
          FastlaneCore::ConfigItem.new(key: :client_id, env_name: 'FL_APPGALLERY_CLIENT_ID', description: 'AppGallery Connect API client ID', sensitive: true)
        ]
      end

      def self.is_supported?(platform)
        platform == :harmonyos
      end

      def self.category
        :production
      end
    end
  end
end
