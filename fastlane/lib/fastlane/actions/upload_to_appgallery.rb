require 'fastlane/helper/appgallery_client'

module Fastlane
  module Actions
    class UploadToAppgalleryAction < Action
      def self.run(params)
        package_path = params[:package_path] || Actions.lane_context[SharedValues::HARMONYOS_HAP_OUTPUT_PATH] || Actions.lane_context[SharedValues::HARMONYOS_APP_OUTPUT_PATH]
        UI.user_error!('No HarmonyOS package found. Pass `package_path` or run `hvigor` first.') if package_path.to_s.empty?
        UI.user_error!("Couldn't find HarmonyOS package at path '#{package_path}'") unless File.file?(package_path)

        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        upload_url = params[:upload_url]
        if upload_url.to_s.empty?
          UI.user_error!('`app_id` is required when `upload_url` is not provided') if params[:app_id].to_s.empty?
          upload_info = client.upload_asset(params[:app_id], package_path, chinese_mainland_flag: params[:chinese_mainland_flag])
          package_info = { 'fileName' => File.basename(package_path), 'objectId' => upload_info['objectId'] }.merge(params[:file_info] || {})
          response = client.update_app_package_info(params[:app_id], package_info, release_type: params[:release_type], release_phase: params[:release_phase])
        else
          response = client.upload_file(upload_url, package_path)
          response = client.update_app_package_info(params[:app_id], params[:file_info], release_type: params[:release_type], release_phase: params[:release_phase]) if params[:file_info]
        end
        UI.success("Uploaded #{File.basename(package_path)} to AppGallery Connect")

        if params[:submit_for_review]
          UI.user_error!('`app_id` is required when `submit_for_review` is true') if params[:app_id].to_s.empty?
          UI.important('Submitting an AppGallery release from upload_to_appgallery is deprecated; use submit_to_appgallery in a separate lane step instead.')
          client.submit(params[:app_id])
        end

        response.respond_to?(:body) ? response.body : response
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
          FastlaneCore::ConfigItem.new(key: :service_account_key_path, env_name: 'FL_APPGALLERY_SERVICE_ACCOUNT_KEY_PATH', description: 'Path to an AppGallery Connect Service Account JSON credential file', sensitive: true, optional: true),
          FastlaneCore::ConfigItem.new(key: :app_id, env_name: 'FL_APPGALLERY_APP_ID', description: 'AppGallery Connect application ID', optional: true),
          FastlaneCore::ConfigItem.new(key: :file_info, env_name: 'FL_APPGALLERY_PACKAGE_INFO', description: 'Optional AppGallery package information fields merged with fileName and objectId', optional: true, type: Hash),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type; 1 is public release', type: Integer, optional: true),
          FastlaneCore::ConfigItem.new(key: :release_phase, env_name: 'FL_APPGALLERY_RELEASE_PHASE', description: 'Release phase; 0 is full and 3 is phased', type: Integer, optional: true),
          FastlaneCore::ConfigItem.new(key: :chinese_mainland_flag, env_name: 'FL_APPGALLERY_CHINESE_MAINLAND_FLAG', description: 'Whether the package is distributed in mainland China: 0 or 1', type: Integer, optional: true, verify_block: proc { |value| UI.user_error!('chinese_mainland_flag must be 0 or 1') unless [0, 1].include?(value) }),
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
