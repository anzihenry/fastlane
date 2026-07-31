require 'fastlane/helper/hdc_helper'

module Fastlane
  module Actions
    class HdcAction < Action
      def self.run(params)
        Helper::HdcHelper.new(hdc_path: params[:hdc_path]).trigger(command: params[:command], serial: params[:serial])
      end

      def self.description
        'Run HDC commands on a HarmonyOS device'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :serial, env_name: 'FL_HARMONYOS_SERIAL', description: 'HarmonyOS device serial to use', default_value: ''),
          FastlaneCore::ConfigItem.new(key: :command, env_name: 'FL_HDC_COMMAND', description: 'Command passed to hdc, for example `shell param get const.product.model`', optional: true),
          FastlaneCore::ConfigItem.new(key: :hdc_path, env_name: 'FL_HDC_PATH', description: 'Path to the hdc binary', default_value: 'hdc')
        ]
      end

      def self.is_supported?(platform)
        platform == :harmonyos
      end

      def self.category
        :building
      end
    end
  end
end
