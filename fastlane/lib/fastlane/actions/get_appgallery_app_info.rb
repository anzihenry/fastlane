require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_APP_INFO = :APPGALLERY_APP_INFO
    end

    class GetAppgalleryAppInfoAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret])
        response = client.app_info(params[:app_id], lang: params[:lang], release_type: params[:release_type])
        Actions.lane_context[SharedValues::APPGALLERY_APP_INFO] = response
        response
      end

      def self.description
        'Fetch HarmonyOS app information from AppGallery Connect'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :lang, env_name: 'FL_APPGALLERY_LANGUAGE', description: 'Language to query, for example `zh-CN`', optional: true),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type accepted by AppGallery Connect', optional: true)
        ]
      end

      def self.output
        [['APPGALLERY_APP_INFO', 'App information returned by AppGallery Connect']]
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
