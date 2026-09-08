require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_DELETE_LANGUAGE_RESPONSE = :APPGALLERY_DELETE_LANGUAGE_RESPONSE
    end

    class DeleteAppgalleryLanguageInfoAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        response = client.delete_language_info(params[:app_id], params[:lang], release_type: params[:release_type])
        Actions.lane_context[SharedValues::APPGALLERY_DELETE_LANGUAGE_RESPONSE] = response
        response
      end

      def self.description
        'Delete non-default localized metadata from an AppGallery Connect HarmonyOS app'
      end

      def self.details
        'AppGallery Connect does not allow deleting the default language.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :lang, env_name: 'FL_APPGALLERY_LANG', description: 'Language code to delete', verify_block: proc { |value| UI.user_error!('No language provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type; 1 is public release', type: Integer, optional: true)
        ]
      end

      def self.output
        [['APPGALLERY_DELETE_LANGUAGE_RESPONSE', 'AppGallery Connect language deletion response']]
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
