require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_CANCEL_REVIEW_RESPONSE = :APPGALLERY_CANCEL_REVIEW_RESPONSE
    end

    class CancelAppgalleryReviewAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(
          api_base: params[:api_base],
          access_token: params[:access_token],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          service_account_key_path: params[:service_account_key_path]
        )
        response = client.cancel_review(params[:app_id], params[:version_id])
        Actions.lane_context[SharedValues::APPGALLERY_CANCEL_REVIEW_RESPONSE] = response
        response
      end

      def self.description
        'Cancel the review of an eligible HarmonyOS AppGallery version'
      end

      def self.details
        'This changes release state. Query the version first and call it only for a version whose AppGallery state allows review cancellation.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :version_id, env_name: 'FL_APPGALLERY_VERSION_ID', description: 'AppGallery version ID whose review should be canceled', verify_block: proc { |value| UI.user_error!('No AppGallery version ID provided') if value.to_s.empty? })
        ]
      end

      def self.output
        [['APPGALLERY_CANCEL_REVIEW_RESPONSE', 'Response returned after canceling review']]
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
