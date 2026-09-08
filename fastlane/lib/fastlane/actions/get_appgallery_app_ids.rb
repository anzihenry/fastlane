require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_APP_IDS = :APPGALLERY_APP_IDS
    end

    class GetAppgalleryAppIdsAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        response = client.app_ids(params[:package_names], package_types: params[:package_types])
        Actions.lane_context[SharedValues::APPGALLERY_APP_IDS] = response
        response
      end

      def self.description
        'Find AppGallery Connect app IDs from HarmonyOS package names'
      end

      def self.available_options
        AppgalleryOptions.common_without_app_id + [
          FastlaneCore::ConfigItem.new(key: :package_names, env_name: 'FL_APPGALLERY_PACKAGE_NAMES', description: 'HarmonyOS package names to query', type: Array, verify_block: proc { |value| UI.user_error!('No package names provided') if value.to_a.empty? }),
          FastlaneCore::ConfigItem.new(key: :package_types, env_name: 'FL_APPGALLERY_PACKAGE_TYPES', description: 'AppGallery package type filters; 7 is HarmonyOS APP', type: Array, default_value: [7])
        ]
      end

      def self.output
        [['APPGALLERY_APP_IDS', 'App IDs returned for the requested package names']]
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
