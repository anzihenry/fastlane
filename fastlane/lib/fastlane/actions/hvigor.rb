require 'pathname'
require 'shellwords'

module Fastlane
  module Actions
    module SharedValues
      HARMONYOS_HAP_OUTPUT_PATH = :HARMONYOS_HAP_OUTPUT_PATH
      HARMONYOS_ALL_HAP_OUTPUT_PATHS = :HARMONYOS_ALL_HAP_OUTPUT_PATHS
      HARMONYOS_APP_OUTPUT_PATH = :HARMONYOS_APP_OUTPUT_PATH
      HARMONYOS_ALL_APP_OUTPUT_PATHS = :HARMONYOS_ALL_APP_OUTPUT_PATHS
      HARMONYOS_HAR_OUTPUT_PATH = :HARMONYOS_HAR_OUTPUT_PATH
      HARMONYOS_ALL_HAR_OUTPUT_PATHS = :HARMONYOS_ALL_HAR_OUTPUT_PATHS
      HARMONYOS_PRODUCT = :HARMONYOS_PRODUCT
      HARMONYOS_BUILD_MODE = :HARMONYOS_BUILD_MODE
    end

    class HvigorAction < Action
      def self.run(params)
        task = params[:task] || params[:tasks]&.join(' ')
        UI.user_error!('Please pass an Hvigor task or tasks') if task.to_s.empty?

        project_dir = params[:project_dir]
        hvigor_path = params[:hvigor_path] || './hvigorw'
        hvigor_path = File.expand_path(hvigor_path, project_dir) unless Pathname.new(hvigor_path).absolute?
        UI.user_error!("Couldn't find hvigorw at path '#{hvigor_path}'") unless File.exist?(hvigor_path)

        properties = params[:properties].to_h
        properties['product'] = params[:product] if params[:product]
        properties['buildMode'] = params[:build_mode] if params[:build_mode]
        property_flags = properties.map { |key, value| "-p #{"#{key}=#{value}".shellescape}" }
        command = [hvigor_path.shellescape, '--mode project', property_flags.join(' '), task, params[:flags]].compact.reject(&:empty?).join(' ')

        Actions.lane_context[SharedValues::HARMONYOS_PRODUCT] = params[:product] if params[:product]
        Actions.lane_context[SharedValues::HARMONYOS_BUILD_MODE] = params[:build_mode] if params[:build_mode]
        result = Action.sh(command, print_command: params[:print_command], print_command_output: params[:print_command_output])

        discover_artifacts(project_dir, params[:artifact_glob])
        result
      end

      def self.discover_artifacts(project_dir, artifact_glob)
        artifacts = Dir[File.join(project_dir, artifact_glob)].map { |path| File.expand_path(path) }.sort
        haps = artifacts.select { |path| path.end_with?('.hap') }
        apps = artifacts.select { |path| path.end_with?('.app') }
        hars = artifacts.select { |path| path.end_with?('.har') }

        Actions.lane_context[SharedValues::HARMONYOS_ALL_HAP_OUTPUT_PATHS] = haps
        Actions.lane_context[SharedValues::HARMONYOS_ALL_APP_OUTPUT_PATHS] = apps
        Actions.lane_context[SharedValues::HARMONYOS_ALL_HAR_OUTPUT_PATHS] = hars
        Actions.lane_context[SharedValues::HARMONYOS_HAP_OUTPUT_PATH] = haps.last
        Actions.lane_context[SharedValues::HARMONYOS_APP_OUTPUT_PATH] = apps.last
        Actions.lane_context[SharedValues::HARMONYOS_HAR_OUTPUT_PATH] = hars.last
      end

      def self.description
        'Run Hvigor tasks to build, test, or package a HarmonyOS app'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :task, env_name: 'FL_HVIGOR_TASK', description: 'Hvigor task to run, for example `assembleApp`', optional: true, conflicting_options: [:tasks]),
          FastlaneCore::ConfigItem.new(key: :tasks, env_name: 'FL_HVIGOR_TASKS', description: 'Multiple Hvigor tasks to run', optional: true, type: Array, conflicting_options: [:task]),
          FastlaneCore::ConfigItem.new(key: :product, env_name: 'FL_HARMONYOS_PRODUCT', description: 'HarmonyOS product name', optional: true),
          FastlaneCore::ConfigItem.new(key: :build_mode, env_name: 'FL_HARMONYOS_BUILD_MODE', description: 'HarmonyOS build mode, for example `debug` or `release`', optional: true),
          FastlaneCore::ConfigItem.new(key: :project_dir, env_name: 'FL_HVIGOR_PROJECT_DIR', description: 'Root directory of the HarmonyOS project', default_value: '.'),
          FastlaneCore::ConfigItem.new(key: :hvigor_path, env_name: 'FL_HVIGOR_PATH', description: 'Path to the Hvigor wrapper', optional: true),
          FastlaneCore::ConfigItem.new(key: :properties, env_name: 'FL_HVIGOR_PROPERTIES', description: 'Additional Hvigor project properties', optional: true, type: Hash),
          FastlaneCore::ConfigItem.new(key: :flags, env_name: 'FL_HVIGOR_FLAGS', description: 'Additional flags passed to Hvigor', optional: true),
          FastlaneCore::ConfigItem.new(key: :artifact_glob, env_name: 'FL_HARMONYOS_ARTIFACT_GLOB', description: 'Glob used to discover HAP, APP, and HAR artifacts', default_value: '**/build/**/*.{hap,app,har}'),
          FastlaneCore::ConfigItem.new(key: :print_command, env_name: 'FL_HVIGOR_PRINT_COMMAND', description: 'Print the Hvigor command before running it', type: Boolean, default_value: true),
          FastlaneCore::ConfigItem.new(key: :print_command_output, env_name: 'FL_HVIGOR_PRINT_COMMAND_OUTPUT', description: 'Print Hvigor command output while running', type: Boolean, default_value: true)
        ]
      end

      def self.output
        [
          ['HARMONYOS_HAP_OUTPUT_PATH', 'Path to the most recent HAP artifact'],
          ['HARMONYOS_ALL_HAP_OUTPUT_PATHS', 'Paths to all discovered HAP artifacts'],
          ['HARMONYOS_APP_OUTPUT_PATH', 'Path to the most recent APP artifact'],
          ['HARMONYOS_ALL_APP_OUTPUT_PATHS', 'Paths to all discovered APP artifacts'],
          ['HARMONYOS_HAR_OUTPUT_PATH', 'Path to the most recent HAR artifact'],
          ['HARMONYOS_ALL_HAR_OUTPUT_PATHS', 'Paths to all discovered HAR artifacts']
        ]
      end

      def self.example_code
        [
          'hvigor(task: "assembleApp", product: "default", build_mode: "release")'
        ]
      end

      def self.category
        :building
      end

      def self.is_supported?(platform)
        platform == :harmonyos
      end
    end
  end
end
