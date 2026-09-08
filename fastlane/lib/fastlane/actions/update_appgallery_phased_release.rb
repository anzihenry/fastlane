require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_PHASED_RELEASE_RESPONSE = :APPGALLERY_PHASED_RELEASE_RESPONSE
    end

    class UpdateAppgalleryPhasedReleaseAction < Action
      def self.run(params)
        updates = [params[:release_phase], params[:state], params[:description], params[:phase_day]]
        UI.user_error!('Provide at least one AppGallery phased release update') if updates.all?(&:nil?)

        client = Helper::AppgalleryClient.new(
          api_base: params[:api_base],
          access_token: params[:access_token],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          service_account_key_path: params[:service_account_key_path]
        )
        response = client.update_phased_release(
          params[:app_id],
          version_id: params[:version_id],
          release_phase: params[:release_phase],
          state: params[:state],
          description: params[:description],
          phase_day: params[:phase_day]
        )
        Actions.lane_context[SharedValues::APPGALLERY_PHASED_RELEASE_RESPONSE] = response
        response
      end

      def self.description
        'Pause, resume, accelerate, or complete an AppGallery phased release'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :version_id, env_name: 'FL_APPGALLERY_VERSION_ID', description: 'AppGallery version ID', verify_block: proc { |value| UI.user_error!('No AppGallery version ID provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :release_phase, env_name: 'FL_APPGALLERY_RELEASE_PHASE', description: '3 to keep phased release or 4 to promote to full release', type: Integer, optional: true, verify_block: proc { |value| UI.user_error!('AppGallery release_phase must be 3 or 4') unless [3, 4].include?(value) }),
          FastlaneCore::ConfigItem.new(key: :state, env_name: 'FL_APPGALLERY_PHASED_RELEASE_STATE', description: 'SUSPEND to pause or RELEASE to resume', optional: true, verify_block: proc { |value| UI.user_error!('AppGallery phased release state must be SUSPEND or RELEASE') unless %w[SUSPEND RELEASE].include?(value) }),
          FastlaneCore::ConfigItem.new(key: :description, env_name: 'FL_APPGALLERY_PHASED_RELEASE_DESCRIPTION', description: 'Optional phased release description', optional: true),
          FastlaneCore::ConfigItem.new(key: :phase_day, env_name: 'FL_APPGALLERY_PHASE_DAY', description: 'Phased day 2 through 7, mapping to 2%, 5%, 10%, 20%, 50%, or 100%', type: Integer, optional: true, verify_block: proc { |value| UI.user_error!('AppGallery phase_day must be between 2 and 7') unless (2..7).cover?(value) })
        ]
      end

      def self.output
        [['APPGALLERY_PHASED_RELEASE_RESPONSE', 'Response returned after updating phased release settings']]
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
