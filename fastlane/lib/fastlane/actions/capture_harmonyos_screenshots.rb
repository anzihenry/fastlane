require 'fileutils'
require 'fastlane/helper/hdc_helper'

module Fastlane
  module Actions
    module SharedValues
      HARMONYOS_SCREENSHOTS_PATH = :HARMONYOS_SCREENSHOTS_PATH
      HARMONYOS_SCREENSHOT_PATHS = :HARMONYOS_SCREENSHOT_PATHS
    end

    class CaptureHarmonyosScreenshotsAction < Action
      def self.run(params)
        output_directory = File.expand_path(params[:output_directory])
        FileUtils.mkdir_p(output_directory)
        serials = params[:serials].to_a
        serials = [params[:serial]] if serials.empty?
        helper = Helper::HdcHelper.new(hdc_path: params[:hdc_path])
        serials.each do |serial|
          command = params[:capture_command]
          command = command.gsub('{{serial}}', serial.to_s).gsub('{{output_directory}}', output_directory)
          helper.trigger(command: command, serial: serial)
        end

        Actions.lane_context[SharedValues::HARMONYOS_SCREENSHOTS_PATH] = output_directory
        Actions.lane_context[SharedValues::HARMONYOS_SCREENSHOT_PATHS] = Dir[File.join(output_directory, params[:screenshot_glob])].map { |path| File.expand_path(path) }.sort
        true
      end

      def self.description
        'Run a HarmonyOS screenshot capture command and expose its output directory'
      end

      def self.details
        'Use `capture_command` for your project-specific HDC capture and file-receive workflow. The command supports `{{serial}}` and `{{output_directory}}` placeholders and runs once for each serial. The action exposes the local output directory and collected image paths for subsequent framing or publishing steps.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :capture_command, env_name: 'FL_HARMONYOS_SCREENSHOT_COMMAND', description: 'HDC command that captures and copies screenshots to output_directory', verify_block: proc { |value| UI.user_error!('No HarmonyOS screenshot command provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :output_directory, env_name: 'FL_HARMONYOS_SCREENSHOTS_PATH', description: 'Local screenshot output directory', default_value: 'fastlane/screenshots'),
          FastlaneCore::ConfigItem.new(key: :serial, env_name: 'FL_HARMONYOS_SERIAL', description: 'HarmonyOS device serial to use', default_value: ''),
          FastlaneCore::ConfigItem.new(key: :serials, env_name: 'FL_HARMONYOS_SERIALS', description: 'HarmonyOS device serials to capture from', optional: true, type: Array, conflicting_options: [:serial]),
          FastlaneCore::ConfigItem.new(key: :screenshot_glob, env_name: 'FL_HARMONYOS_SCREENSHOT_GLOB', description: 'Glob used to collect local screenshot files', default_value: '**/*.{png,jpg,jpeg}'),
          FastlaneCore::ConfigItem.new(key: :hdc_path, env_name: 'FL_HDC_PATH', description: 'Path to the hdc binary', default_value: 'hdc')
        ]
      end

      def self.output
        [
          ['HARMONYOS_SCREENSHOTS_PATH', 'Local screenshot output directory'],
          ['HARMONYOS_SCREENSHOT_PATHS', 'Collected local screenshot file paths']
        ]
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
