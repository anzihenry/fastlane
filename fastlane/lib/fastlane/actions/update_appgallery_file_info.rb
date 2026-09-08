require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_FILE_INFO_RESPONSE = :APPGALLERY_FILE_INFO_RESPONSE
    end

    class UpdateAppgalleryFileInfoAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        response = client.update_app_file_info(params[:app_id], params[:file_info], release_type: params[:release_type], release_phase: params[:release_phase])
        Actions.lane_context[SharedValues::APPGALLERY_FILE_INFO_RESPONSE] = response
        response
      end

      def self.description
        'Associate uploaded icons, screenshots, and videos with an AppGallery Connect HarmonyOS app'
      end

      def self.details
        'Pass AppGallery object IDs in appIconList, screenShotList, introVideoList, rcmdVideoList, or rcmdPicList.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :file_info, env_name: 'FL_APPGALLERY_FILE_INFO', description: 'Localized AppGallery store asset information', type: Hash, verify_block: proc { |value| UI.user_error!('No file information provided') if value.to_h.empty? }),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type; 1 is public release', type: Integer, optional: true),
          FastlaneCore::ConfigItem.new(key: :release_phase, env_name: 'FL_APPGALLERY_RELEASE_PHASE', description: 'Release phase; 0 is full and 3 is phased', type: Integer, optional: true)
        ]
      end

      def self.output
        [['APPGALLERY_FILE_INFO_RESPONSE', 'AppGallery Connect file information update response']]
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
