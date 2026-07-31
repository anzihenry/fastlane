module Fastlane
  class SetupHarmonyos < Setup
    def setup_harmonyos
      self.platform = :harmonyos
      self.is_swift_fastfile = false

      welcome_to_fastlane
      self.fastfile_content = fastfile_template_content.gsub(':ios', ':harmonyos')
      self.appfile_content = appfile_template_content
      FastlaneCore::FastlaneFolder.create_folder!

      append_lane([
                    'desc "Build the HarmonyOS application"',
                    'lane :build do',
                    '  build_harmonyos_app',
                    'end'
                  ])
      append_lane([
                    'desc "Run HarmonyOS project tests"',
                    'lane :test do',
                    '  hvigor(task: "test")',
                    'end'
                  ])

      self.lane_to_mention = 'build'
      finish_up
    end
  end
end
