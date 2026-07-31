require 'fastlane/helper/hdc_helper'

module Fastlane
  module Actions
    class HdcDevicesAction < Action
      def self.run(params)
        Helper::HdcHelper.new(hdc_path: params[:hdc_path]).load_all_devices
      end

      def self.description
        'Get connected HarmonyOS device serials'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :hdc_path, env_name: 'FL_HDC_PATH', description: 'Path to the hdc binary', default_value: 'hdc')
        ]
      end

      def self.return_type
        :array_of_strings
      end

      def self.is_supported?(platform)
        platform == :harmonyos
      end

      def self.category
        :misc
      end
    end
  end
end
