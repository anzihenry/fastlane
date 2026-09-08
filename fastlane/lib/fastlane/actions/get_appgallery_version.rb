require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_FILE_INFO = :APPGALLERY_FILE_INFO
    end

    class GetAppgalleryVersionAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret])
        response = client.app_file_info(params[:app_id])
        Actions.lane_context[SharedValues::APPGALLERY_FILE_INFO] = response
        response
      end

      def self.description
        'Fetch AppGallery Connect package information for a HarmonyOS app'
      end

      def self.output
        [['APPGALLERY_FILE_INFO', 'Package and file information returned by AppGallery Connect']]
      end

      def self.available_options
        AppgalleryOptions.common
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
