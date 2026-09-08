require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    class UpdateAppgalleryAppInfoAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret])
        client.update_app_info(params[:app_id], params[:app_info])
      end

      def self.description
        'Update HarmonyOS app information in AppGallery Connect'
      end

      def self.details
        'Pass only fields documented by AppGallery Connect for the target application. This action does not submit a release for review.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :app_info, env_name: 'FL_APPGALLERY_APP_INFO', description: 'AppGallery Connect app information JSON to update', type: Hash, verify_block: proc { |value| UI.user_error!('No app information provided') if value.to_h.empty? })
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
