require 'fastlane/actions/hvigor'

module Fastlane
  module Actions
    class BuildHarmonyosAppAction < HvigorAction
      def self.run(params)
        params[:task] ||= 'assembleApp'
        super(params)
      end

      def self.description
        'Build a HarmonyOS app with Hvigor'
      end
    end
  end
end
