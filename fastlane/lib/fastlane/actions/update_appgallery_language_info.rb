require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_LANGUAGE_INFO_RESPONSE = :APPGALLERY_LANGUAGE_INFO_RESPONSE
    end

    class UpdateAppgalleryLanguageInfoAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        response = client.update_language_info(params[:app_id], params[:language_info], release_type: params[:release_type], release_phase: params[:release_phase])
        Actions.lane_context[SharedValues::APPGALLERY_LANGUAGE_INFO_RESPONSE] = response
        response
      end

      def self.description
        'Create or update localized AppGallery Connect metadata for a HarmonyOS app'
      end

      def self.details
        'The language_info hash must contain lang and may contain appName, appDesc, briefInfo, and newFeatures.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :language_info, env_name: 'FL_APPGALLERY_LANGUAGE_INFO', description: 'Localized AppGallery metadata including lang', type: Hash, verify_block: proc { |value| UI.user_error!('language_info must include lang') if (value['lang'] || value[:lang]).to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type; 1 is public release', type: Integer, optional: true),
          FastlaneCore::ConfigItem.new(key: :release_phase, env_name: 'FL_APPGALLERY_RELEASE_PHASE', description: 'Release phase; 0 is full and 3 is phased', type: Integer, optional: true)
        ]
      end

      def self.output
        [['APPGALLERY_LANGUAGE_INFO_RESPONSE', 'AppGallery Connect language update response']]
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
