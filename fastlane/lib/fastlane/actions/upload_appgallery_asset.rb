require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_ASSET_OBJECT_ID = :APPGALLERY_ASSET_OBJECT_ID
      APPGALLERY_ASSET_UPLOAD_INFO = :APPGALLERY_ASSET_UPLOAD_INFO
    end

    class UploadAppgalleryAssetAction < Action
      def self.run(params)
        path = File.expand_path(params[:asset_path])
        UI.user_error!("Couldn't find AppGallery asset at path '#{path}'") unless File.file?(path)

        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        upload_info = client.upload_asset(params[:app_id], path, chinese_mainland_flag: params[:chinese_mainland_flag])
        Actions.lane_context[SharedValues::APPGALLERY_ASSET_OBJECT_ID] = upload_info['objectId']
        Actions.lane_context[SharedValues::APPGALLERY_ASSET_UPLOAD_INFO] = upload_info
        UI.success("Uploaded #{File.basename(path)} to AppGallery Connect")
        upload_info['objectId']
      end

      def self.description
        'Upload an AppGallery Connect icon, screenshot, video, or other store asset'
      end

      def self.details
        'Requests a short-lived OBS URL, uploads the file with the signed headers returned by AppGallery Connect, and returns the object ID used by metadata APIs.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :asset_path, env_name: 'FL_APPGALLERY_ASSET_PATH', description: 'Path to the store asset to upload', verify_block: proc { |value| UI.user_error!('No asset path provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :chinese_mainland_flag, env_name: 'FL_APPGALLERY_CHINESE_MAINLAND_FLAG', description: 'Whether the package is distributed in mainland China: 0 or 1', type: Integer, optional: true, verify_block: proc { |value| UI.user_error!('chinese_mainland_flag must be 0 or 1') unless [0, 1].include?(value) })
        ]
      end

      def self.output
        [
          ['APPGALLERY_ASSET_OBJECT_ID', 'Uploaded asset object ID'],
          ['APPGALLERY_ASSET_UPLOAD_INFO', 'Upload URL information returned by AppGallery Connect']
        ]
      end

      def self.return_value
        'The uploaded asset object ID'
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
