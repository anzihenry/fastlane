require 'fileutils'
require 'fastlane/helper/hdc_helper'

module Fastlane
  module Actions
    module SharedValues
      HARMONYOS_SCREENSHOTS_PATH = :HARMONYOS_SCREENSHOTS_PATH
    end

    class CaptureHarmonyosScreenshotsAction < Action
      def self.run(params)
        output_directory = File.expand_path(params[:output_directory])
        FileUtils.mkdir_p(output_directory)
        Helper::HdcHelper.new(hdc_path: params[:hdc_path]).trigger(command: params[:capture_command], serial: params[:serial])
        Actions.lane_context[SharedValues::HARMONYOS_SCREENSHOTS_PATH] = output_directory
        true
      end

      def self.description
        'Run a HarmonyOS screenshot capture command and expose its output directory'
      end

      def self.details
        'Use `capture_command` for your project-specific HDC capture and file-receive workflow. The action creates and exposes the local output directory for subsequent framing or publishing steps.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :capture_command, env_name: 'FL_HARMONYOS_SCREENSHOT_COMMAND', description: 'HDC command that captures and copies screenshots to output_directory', verify_block: proc { |value| UI.user_error!('No HarmonyOS screenshot command provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :output_directory, env_name: 'FL_HARMONYOS_SCREENSHOTS_PATH', description: 'Local screenshot output directory', default_value: 'fastlane/screenshots'),
          FastlaneCore::ConfigItem.new(key: :serial, env_name: 'FL_HARMONYOS_SERIAL', description: 'HarmonyOS device serial to use', default_value: ''),
          FastlaneCore::ConfigItem.new(key: :hdc_path, env_name: 'FL_HDC_PATH', description: 'Path to the hdc binary', default_value: 'hdc')
        ]
      end

      def self.output
        [['HARMONYOS_SCREENSHOTS_PATH', 'Local screenshot output directory']]
      end

      def self.is_supported?(platform)
        platform == :harmonyos
      end

      def self.category
        :screenshots
      end
    end
  end
end
