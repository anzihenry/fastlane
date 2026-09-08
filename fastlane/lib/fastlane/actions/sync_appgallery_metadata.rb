require 'json'
require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_METADATA_SYNC_RESULT = :APPGALLERY_METADATA_SYNC_RESULT
    end

    class SyncAppgalleryMetadataAction < Action
      TEXT_FILES = {
        'title.txt' => 'appName',
        'short_description.txt' => 'briefInfo',
        'full_description.txt' => 'appDesc',
        File.join('changelogs', 'default.txt') => 'newFeatures'
      }.freeze
      IMAGE_EXTENSIONS = 'png,jpg,jpeg'.freeze

      def self.run(params)
        metadata_path = File.expand_path(params[:metadata_path])
        UI.user_error!("AppGallery metadata directory does not exist at '#{metadata_path}'") unless File.directory?(metadata_path)

        plan = build_plan(metadata_path)
        validate_plan!(plan)
        if params[:validate_only]
          Actions.lane_context[SharedValues::APPGALLERY_METADATA_SYNC_RESULT] = plan
          return plan
        end

        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        sync_metadata(client, params, plan) unless params[:skip_upload_metadata]
        sync_assets(client, params, plan) unless params[:skip_upload_assets]
        Actions.lane_context[SharedValues::APPGALLERY_METADATA_SYNC_RESULT] = plan
        plan
      end

      def self.build_plan(metadata_path)
        app_path = File.join(metadata_path, 'app.json')
        app_info = File.file?(app_path) ? JSON.parse(File.read(app_path)) : {}
        languages = Dir.children(metadata_path).sort.filter_map do |lang|
          directory = File.join(metadata_path, lang)
          next unless File.directory?(directory)

          language_info = { 'lang' => lang }
          TEXT_FILES.each do |relative_path, key|
            path = File.join(directory, relative_path)
            language_info[key] = File.read(path).strip if File.file?(path)
          end
          devices = Dir.glob(File.join(directory, 'images', '*')).filter_map do |device_directory|
            next unless File.directory?(device_directory)

            icon_paths = Dir.glob(File.join(device_directory, "icon.{#{IMAGE_EXTENSIONS}}"), File::FNM_EXTGLOB).sort
            screenshot_paths = Dir.glob(File.join(device_directory, 'screenshots', "*.{#{IMAGE_EXTENSIONS}}"), File::FNM_EXTGLOB).sort
            next if icon_paths.empty? && screenshot_paths.empty?

            { 'deviceType' => File.basename(device_directory), 'icons' => icon_paths, 'screenshots' => screenshot_paths }
          end
          next if language_info.length == 1 && devices.empty?

          { 'lang' => lang, 'languageInfo' => language_info, 'devices' => devices }
        end
        { 'metadataPath' => metadata_path, 'appInfo' => app_info, 'languages' => languages }
      rescue JSON::ParserError => ex
        UI.user_error!("Invalid AppGallery app.json: #{ex.message}")
      end
      private_class_method :build_plan

      def self.validate_plan!(plan)
        UI.user_error!('AppGallery app.json must contain a JSON object') unless plan['appInfo'].kind_of?(Hash)
        plan['languages'].each do |language|
          language['devices'].each do |device|
            device_type = Integer(device['deviceType'], exception: false)
            UI.user_error!("AppGallery device directory must be a numeric deviceType: #{device['deviceType']}") unless device_type&.positive?
            UI.user_error!("Only one AppGallery icon is allowed for #{language['lang']}/#{device['deviceType']}") if device['icons'].length > 1
            UI.user_error!("AppGallery supports at most 20 screenshots for #{language['lang']}/#{device['deviceType']}") if device['screenshots'].length > 20
            device['deviceType'] = device_type
          end
        end
      end
      private_class_method :validate_plan!

      def self.sync_metadata(client, params, plan)
        client.update_app_info(params[:app_id], plan['appInfo']) unless plan['appInfo'].empty?
        plan['languages'].each do |language|
          next if language['languageInfo'].length == 1

          client.update_language_info(params[:app_id], language['languageInfo'], release_type: params[:release_type], release_phase: params[:release_phase])
        end
      end
      private_class_method :sync_metadata

      def self.sync_assets(client, params, plan)
        app_icons = []
        screenshots = []
        plan['languages'].each do |language|
          icon_files = []
          screenshot_files = []
          language['devices'].each do |device|
            icon_ids = device['icons'].map { |path| client.upload_asset(params[:app_id], path, chinese_mainland_flag: params[:chinese_mainland_flag])['objectId'] }
            screenshot_ids = device['screenshots'].map { |path| client.upload_asset(params[:app_id], path, chinese_mainland_flag: params[:chinese_mainland_flag])['objectId'] }
            icon_files << file_info(device['deviceType'], icon_ids, params[:show_type]) unless icon_ids.empty?
            screenshot_files << file_info(device['deviceType'], screenshot_ids, params[:show_type]) unless screenshot_ids.empty?
          end
          app_icons << { 'lang' => language['lang'], 'fileInfoList' => icon_files } unless icon_files.empty?
          screenshots << { 'lang' => language['lang'], 'fileInfoList' => screenshot_files } unless screenshot_files.empty?
        end
        return if app_icons.empty? && screenshots.empty?

        body = {}
        body['appIconList'] = app_icons unless app_icons.empty?
        body['screenShotList'] = screenshots unless screenshots.empty?
        client.update_app_file_info(params[:app_id], body, release_type: params[:release_type], release_phase: params[:release_phase])
        plan['fileInfo'] = body
      end
      private_class_method :sync_assets

      def self.file_info(device_type, object_ids, show_type)
        { 'deviceType' => device_type, 'objectIdList' => object_ids, 'showType' => show_type }
      end
      private_class_method :file_info

      def self.description
        'Sync Android-style local metadata, icons, and screenshots to AppGallery Connect'
      end

      def self.details
        'Reads app.json plus locale text files and locale/images/deviceType asset directories. Use validate_only to inspect the complete plan without making network requests.'
      end

      def self.available_options
        AppgalleryOptions.common + [
          FastlaneCore::ConfigItem.new(key: :metadata_path, env_name: 'FL_APPGALLERY_METADATA_PATH', description: 'AppGallery metadata directory', default_value: 'fastlane/metadata/harmonyos'),
          FastlaneCore::ConfigItem.new(key: :release_type, env_name: 'FL_APPGALLERY_RELEASE_TYPE', description: 'Release type; 1 is public release', type: Integer, optional: true),
          FastlaneCore::ConfigItem.new(key: :release_phase, env_name: 'FL_APPGALLERY_RELEASE_PHASE', description: 'Release phase; 0 is full and 3 is phased', type: Integer, optional: true),
          FastlaneCore::ConfigItem.new(key: :show_type, env_name: 'FL_APPGALLERY_ASSET_SHOW_TYPE', description: 'Asset orientation: 0 is portrait and 1 is landscape', type: Integer, default_value: 0, verify_block: proc { |value| UI.user_error!('show_type must be 0 or 1') unless [0, 1].include?(value) }),
          FastlaneCore::ConfigItem.new(key: :chinese_mainland_flag, env_name: 'FL_APPGALLERY_CHINESE_MAINLAND_FLAG', description: 'Whether packages are distributed in mainland China: 0 or 1', type: Integer, optional: true, verify_block: proc { |value| UI.user_error!('chinese_mainland_flag must be 0 or 1') unless [0, 1].include?(value) }),
          FastlaneCore::ConfigItem.new(key: :skip_upload_metadata, env_name: 'FL_APPGALLERY_SKIP_UPLOAD_METADATA', description: 'Skip basic and localized text metadata', type: Boolean, default_value: false),
          FastlaneCore::ConfigItem.new(key: :skip_upload_assets, env_name: 'FL_APPGALLERY_SKIP_UPLOAD_ASSETS', description: 'Skip icons and screenshots', type: Boolean, default_value: false),
          FastlaneCore::ConfigItem.new(key: :validate_only, env_name: 'FL_APPGALLERY_VALIDATE_ONLY', description: 'Validate and return the local sync plan without network requests', type: Boolean, default_value: false)
        ]
      end

      def self.output
        [['APPGALLERY_METADATA_SYNC_RESULT', 'Validated metadata plan and uploaded file information']]
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
