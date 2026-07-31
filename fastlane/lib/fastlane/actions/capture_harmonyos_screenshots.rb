require 'fileutils'
require 'fastlane/helper/hdc_helper'

module Fastlane
  module Actions
    module SharedValues
      HARMONYOS_SCREENSHOTS_PATH = :HARMONYOS_SCREENSHOTS_PATH
      HARMONYOS_SCREENSHOT_PATHS = :HARMONYOS_SCREENSHOT_PATHS
      HARMONYOS_SCREENSHOTS_BY_VARIANT = :HARMONYOS_SCREENSHOTS_BY_VARIANT
    end

    class CaptureHarmonyosScreenshotsAction < Action
      def self.run(params)
        output_directory = File.expand_path(params[:output_directory])
        FileUtils.mkdir_p(output_directory)
        serials = params[:serials].to_a
        serials = [params[:serial]] if serials.empty?
        locales = params[:locales].to_a
        locales = [nil] if locales.empty?
        helper = Helper::HdcHelper.new(hdc_path: params[:hdc_path])
        screenshots_by_variant = {}
        locales.each do |locale|
          serials.each do |serial|
            variant_directory = variant_output_directory(output_directory, locale, serial, locales.length, serials.length)
            FileUtils.mkdir_p(variant_directory)
            command = params[:capture_command]
            command = command.gsub('{{serial}}', serial.to_s).gsub('{{locale}}', locale.to_s).gsub('{{output_directory}}', variant_directory)
            helper.trigger(command: command, serial: serial)
            screenshots_by_variant[variant_key(locale, serial)] = Dir[File.join(variant_directory, params[:screenshot_glob])].map { |path| File.expand_path(path) }.sort
          end
        end

        Actions.lane_context[SharedValues::HARMONYOS_SCREENSHOTS_PATH] = output_directory
        Actions.lane_context[SharedValues::HARMONYOS_SCREENSHOTS_BY_VARIANT] = screenshots_by_variant
        Actions.lane_context[SharedValues::HARMONYOS_SCREENSHOT_PATHS] = screenshots_by_variant.values.flatten.sort
        true
      end

      def self.description
        'Run a HarmonyOS screenshot capture command and expose its output directory'
      end

      def self.details
        'Use `capture_command` for your project-specific HDC capture and file-receive workflow. The command supports `{{serial}}`, `{{locale}}`, and `{{output_directory}}` placeholders and runs once for each device/locale combination. The action exposes the local output directory and collected image paths for subsequent framing or publishing steps.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :capture_command, env_name: 'FL_HARMONYOS_SCREENSHOT_COMMAND', description: 'HDC command that captures and copies screenshots to output_directory', verify_block: proc { |value| UI.user_error!('No HarmonyOS screenshot command provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :output_directory, env_name: 'FL_HARMONYOS_SCREENSHOTS_PATH', description: 'Local screenshot output directory', default_value: 'fastlane/screenshots'),
          FastlaneCore::ConfigItem.new(key: :serial, env_name: 'FL_HARMONYOS_SERIAL', description: 'HarmonyOS device serial to use', default_value: ''),
          FastlaneCore::ConfigItem.new(key: :serials, env_name: 'FL_HARMONYOS_SERIALS', description: 'HarmonyOS device serials to capture from', optional: true, type: Array, conflicting_options: [:serial]),
          FastlaneCore::ConfigItem.new(key: :locales, env_name: 'FL_HARMONYOS_SCREENSHOT_LOCALES', description: 'Locales to capture, for example `["en-US", "zh-CN"]`', optional: true, type: Array),
          FastlaneCore::ConfigItem.new(key: :screenshot_glob, env_name: 'FL_HARMONYOS_SCREENSHOT_GLOB', description: 'Glob used to collect local screenshot files', default_value: '**/*.{png,jpg,jpeg}'),
          FastlaneCore::ConfigItem.new(key: :hdc_path, env_name: 'FL_HDC_PATH', description: 'Path to the hdc binary', default_value: 'hdc')
        ]
      end

      def self.output
        [
          ['HARMONYOS_SCREENSHOTS_PATH', 'Local screenshot output directory'],
          ['HARMONYOS_SCREENSHOT_PATHS', 'Collected local screenshot file paths'],
          ['HARMONYOS_SCREENSHOTS_BY_VARIANT', 'Collected screenshot paths grouped by locale and device serial']
        ]
      end

      def self.is_supported?(platform)
        platform == :harmonyos
      end

      def self.category
        :screenshots
      end

      def self.variant_output_directory(base_directory, locale, serial, locale_count, serial_count)
        parts = [base_directory]
        parts << locale if locale_count > 1
        parts << (serial.to_s.empty? ? 'default-device' : serial) if serial_count > 1
        File.join(parts)
      end

      def self.variant_key(locale, serial)
        [locale || 'default-locale', serial.to_s.empty? ? 'default-device' : serial].join('/')
      end
    end
  end
end
