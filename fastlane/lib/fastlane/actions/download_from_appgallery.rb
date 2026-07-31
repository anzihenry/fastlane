require 'fileutils'
require 'fastlane/helper/appgallery_client'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_DOWNLOADED_PACKAGE_PATH = :APPGALLERY_DOWNLOADED_PACKAGE_PATH
    end

    class DownloadFromAppgalleryAction < Action
      def self.run(params)
        output_path = File.expand_path(params[:output_path])
        FileUtils.mkdir_p(File.dirname(output_path))
        client = Helper::AppgalleryClient.new
        result = client.download_file(params[:download_url], output_path)
        Actions.lane_context[SharedValues::APPGALLERY_DOWNLOADED_PACKAGE_PATH] = result
        result
      end

      def self.description
        'Download a HarmonyOS package from an AppGallery-provided URL'
      end

      def self.details
        'Obtain the package URL through AppGallery Connect or an approved release workflow, then pass it explicitly. This action never discovers or exposes private download URLs.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :download_url, env_name: 'FL_APPGALLERY_DOWNLOAD_URL', description: 'AppGallery package download URL', verify_block: proc { |value| UI.user_error!('No AppGallery download URL provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :output_path, env_name: 'FL_APPGALLERY_DOWNLOAD_PATH', description: 'Local destination path for the downloaded package', default_value: 'fastlane/appgallery/app.hap')
        ]
      end

      def self.output
        [['APPGALLERY_DOWNLOADED_PACKAGE_PATH', 'Local path of the downloaded package']]
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
