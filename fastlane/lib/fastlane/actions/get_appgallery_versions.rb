require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_VERSIONS = :APPGALLERY_VERSIONS
    end

    class GetAppgalleryVersionsAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(
          api_base: params[:api_base],
          access_token: params[:access_token],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          service_account_key_path: params[:service_account_key_path]
        )
        response = client.versions(params[:app_id], package_name: params[:package_name], state: params[:state])
        Actions.lane_context[SharedValues::APPGALLERY_VERSIONS] = response
        response
      end

      def self.description
        'List all commercial and test versions of a HarmonyOS app in AppGallery Connect'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :package_name, env_name: 'FL_APPGALLERY_PACKAGE_NAME', description: 'Optional HarmonyOS package name filter', optional: true),
          FastlaneCore::ConfigItem.new(key: :state, env_name: 'FL_APPGALLERY_VERSION_STATE', description: 'Optional list of version states', type: Array, optional: true)
        ]
      end

      def self.output
        [['APPGALLERY_VERSIONS', 'Version list returned by AppGallery Connect']]
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
