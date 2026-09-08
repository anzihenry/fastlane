require 'fastlane/helper/appgallery_client'

module Fastlane
  module Actions
    class UploadToAppgalleryAction < Action
      def self.run(params)
        package_path = params[:package_path] || Actions.lane_context[SharedValues::HARMONYOS_HAP_OUTPUT_PATH] || Actions.lane_context[SharedValues::HARMONYOS_APP_OUTPUT_PATH]
        UI.user_error!('No HarmonyOS package found. Pass `package_path` or run `hvigor` first.') if package_path.to_s.empty?
        UI.user_error!("Couldn't find HarmonyOS package at path '#{package_path}'") unless File.file?(package_path)

        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret])
        upload_url = params[:upload_url]
        if upload_url.to_s.empty?
          UI.user_error!('`app_id` is required when `upload_url` is not provided') if params[:app_id].to_s.empty?
          upload_url = client.upload_url(params[:app_id], File.extname(package_path).delete_prefix('.'))
        end
        response = client.upload_file(upload_url, package_path)
        UI.success("Uploaded #{File.basename(package_path)} to AppGallery Connect")

        client.update_app_file_info(params[:app_id], params[:file_info]) if params[:file_info]

        if params[:submit_for_review]
          UI.user_error!('`app_id` is required when `submit_for_review` is true') if params[:app_id].to_s.empty?
          UI.important('Submitting an AppGallery release from upload_to_appgallery is deprecated; use submit_to_appgallery in a separate lane step instead.')
          client.submit(params[:app_id])
        end

        response.body
      end

      def self.description
        'Upload a HarmonyOS package to an AppGallery Connect upload URL'
      end

      def self.details
        'This action uploads only by default. Obtain the upload URL and complete app file information first; set submit_for_review to submit an already configured release.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :upload_url, env_name: 'FL_APPGALLERY_UPLOAD_URL', description: 'Pre-signed AppGallery Connect URL for this package; obtained automatically when omitted', optional: true),
          FastlaneCore::ConfigItem.new(key: :package_path, env_name: 'FL_HARMONYOS_PACKAGE_PATH', description: 'Path to a HAP or APP package', optional: true),
          FastlaneCore::ConfigItem.new(key: :api_base, env_name: 'FL_APPGALLERY_API_BASE', description: 'AppGallery Connect API base URL', default_value: Helper::AppgalleryClient::DEFAULT_API_BASE),
          FastlaneCore::ConfigItem.new(key: :access_token, env_name: 'FL_APPGALLERY_ACCESS_TOKEN', description: 'AppGallery Connect API access token', sensitive: true, optional: true),
          FastlaneCore::ConfigItem.new(key: :client_id, env_name: 'FL_APPGALLERY_CLIENT_ID', description: 'AppGallery Connect API client ID', sensitive: true, optional: true),
          FastlaneCore::ConfigItem.new(key: :client_secret, env_name: 'FL_APPGALLERY_CLIENT_SECRET', description: 'AppGallery Connect API client secret used to obtain an access token', sensitive: true, optional: true),
          FastlaneCore::ConfigItem.new(key: :app_id, env_name: 'FL_APPGALLERY_APP_ID', description: 'AppGallery Connect application ID', optional: true),
          FastlaneCore::ConfigItem.new(key: :file_info, env_name: 'FL_APPGALLERY_FILE_INFO', description: 'AppGallery Connect file information JSON to update after upload', optional: true, type: Hash),
          FastlaneCore::ConfigItem.new(key: :submit_for_review, env_name: 'FL_APPGALLERY_SUBMIT_FOR_REVIEW', description: 'Submit a configured release after upload', type: Boolean, default_value: false)
        ]
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
