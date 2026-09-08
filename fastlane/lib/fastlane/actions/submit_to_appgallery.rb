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
        release_info = {
          'releaseTime' => params[:release_time],
          'remark' => params[:remark],
          'releaseType' => params[:release_type],
          'releasePhase' => params[:release_phase],
          'phasedReleaseDescription' => params[:phased_release_description]
        }.compact
        if params[:release_phase] == 3 && params[:phased_release_description].to_s.empty?
          UI.user_error!('`phased_release_description` is required for a phased release')
        end

        response = client.submit(params[:app_id], release_info: release_info)
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
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :release_time, env_name: 'FL_APPGALLERY_RELEASE_TIME', description: 'Optional release time in yyyy-MM-ddTHH:mm:ssZZ format', optional: true),
          FastlaneCore::ConfigItem.new(key: :remark, env_name: 'FL_APPGALLERY_RELEASE_REMARK', description: 'Optional review remark containing 10 to 300 characters', optional: true),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type; HarmonyOS public release is 1', type: Integer, default_value: 1, verify_block: proc { |value| UI.user_error!('AppGallery release_type must be 1') unless value == 1 }),
          FastlaneCore::ConfigItem.new(key: :release_phase, env_name: 'FL_APPGALLERY_RELEASE_PHASE', description: '0 for full release or 3 for seven-day phased release', type: Integer, default_value: 0, verify_block: proc { |value| UI.user_error!('AppGallery release_phase must be 0 or 3') unless [0, 3].include?(value) }),
          FastlaneCore::ConfigItem.new(key: :phased_release_description, env_name: 'FL_APPGALLERY_PHASED_RELEASE_DESCRIPTION', description: 'Phased release description, required when release_phase is 3', optional: true)
        ]
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
