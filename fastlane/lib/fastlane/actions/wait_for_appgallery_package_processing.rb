require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_PACKAGE_STATES = :APPGALLERY_PACKAGE_STATES
    end

    class WaitForAppgalleryPackageProcessingAction < Action
      READY = 0
      PROCESSING = 1
      FAILED = 2

      def self.run(params)
        client = Helper::AppgalleryClient.new(
          api_base: params[:api_base],
          access_token: params[:access_token],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          service_account_key_path: params[:service_account_key_path]
        )
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + params[:timeout]

        loop do
          response = client.package_compile_status(params[:app_id], params[:package_ids])
          states = response.fetch('pkgStateList', [])
          UI.user_error!('AppGallery Connect returned no package states') if states.empty?

          statuses = states.map { |state| state['successStatus'] }
          failed_ids = states.select { |state| state['successStatus'] == FAILED }.map { |state| state['pkgId'] }
          UI.user_error!("AppGallery package processing failed for: #{failed_ids.join(', ')}") unless failed_ids.empty?
          if statuses.all?(READY)
            Actions.lane_context[SharedValues::APPGALLERY_PACKAGE_STATES] = response
            UI.success('All AppGallery packages finished processing')
            return response
          end

          unknown_statuses = statuses - [READY, PROCESSING, FAILED]
          UI.user_error!("AppGallery Connect returned unknown package states: #{unknown_statuses.join(', ')}") unless unknown_statuses.empty?
          UI.user_error!("Timed out waiting for AppGallery package processing after #{params[:timeout]} seconds") if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          UI.message('AppGallery packages are still processing')
          sleep(params[:interval])
        end
      end

      def self.description
        'Wait until AppGallery Connect finishes processing HarmonyOS packages'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :package_ids, env_name: 'FL_APPGALLERY_PACKAGE_IDS', description: 'Package IDs returned when package information is updated', type: Array, verify_block: proc { |value| UI.user_error!('No AppGallery package IDs provided') if value.to_a.empty? }),
          FastlaneCore::ConfigItem.new(key: :interval, env_name: 'FL_APPGALLERY_POLL_INTERVAL', description: 'Seconds between package status checks', type: Integer, default_value: 10),
          FastlaneCore::ConfigItem.new(key: :timeout, env_name: 'FL_APPGALLERY_POLL_TIMEOUT', description: 'Maximum seconds to wait for package processing', type: Integer, default_value: 300)
        ]
      end

      def self.output
        [['APPGALLERY_PACKAGE_STATES', 'Final package states returned by AppGallery Connect']]
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
