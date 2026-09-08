module Fastlane
  module Actions
    module AppgalleryOptions
      def self.common
        common_without_app_id + [
          FastlaneCore::ConfigItem.new(key: :app_id, env_name: 'FL_APPGALLERY_APP_ID', description: 'AppGallery Connect application ID', verify_block: proc { |value| UI.user_error!('No AppGallery application ID provided') if value.to_s.empty? })
        ]
      end

      def self.common_without_app_id
        [
          FastlaneCore::ConfigItem.new(key: :api_base, env_name: 'FL_APPGALLERY_API_BASE', description: 'AppGallery Connect API base URL', default_value: Helper::AppgalleryClient::DEFAULT_API_BASE),
          FastlaneCore::ConfigItem.new(key: :access_token, env_name: 'FL_APPGALLERY_ACCESS_TOKEN', description: 'AppGallery Connect API access token; obtained automatically when client_secret is provided', sensitive: true, optional: true),
          FastlaneCore::ConfigItem.new(key: :client_id, env_name: 'FL_APPGALLERY_CLIENT_ID', description: 'AppGallery Connect API client ID', sensitive: true),
          FastlaneCore::ConfigItem.new(key: :client_secret, env_name: 'FL_APPGALLERY_CLIENT_SECRET', description: 'AppGallery Connect API client secret used to obtain an access token', sensitive: true, optional: true)
        ]
      end
    end
  end
end
