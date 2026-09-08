require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_SUBMIT_RESPONSE = :APPGALLERY_SUBMIT_RESPONSE
    end

    class SubmitToAppgalleryAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        response = client.submit(params[:app_id])
        Actions.lane_context[SharedValues::APPGALLERY_SUBMIT_RESPONSE] = response
        response
      end

      def self.description
        'Explicitly submit a configured HarmonyOS AppGallery release for review'
      end

      def self.details
        'Call this only after uploading the package and updating AppGallery file information. AppGallery processes packages asynchronously, so a newly uploaded package may not be ready for submission immediately.'
      end

      def self.available_options
        AppgalleryOptions.common
      end

      def self.output
        [['APPGALLERY_SUBMIT_RESPONSE', 'Response returned by AppGallery Connect when the release is submitted']]
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
