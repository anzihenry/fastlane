require 'fastlane/helper/appgallery_client'
require 'fastlane/actions/appgallery_options'

module Fastlane
  module Actions
    module SharedValues
      APPGALLERY_APP_ID = :APPGALLERY_APP_ID
    end

    class EnsureAppgalleryAppAction < Action
      def self.run(params)
        client = Helper::AppgalleryClient.new(api_base: params[:api_base], access_token: params[:access_token], client_id: params[:client_id], client_secret: params[:client_secret], service_account_key_path: params[:service_account_key_path])
        response = client.app_ids([params[:package_name]], package_types: params[:package_types])
        app_ids = find_app_ids(response, params[:package_name]).uniq

        if app_ids.empty?
          UI.user_error!("No AppGallery Connect HarmonyOS app exists for #{params[:package_name]}. The Publishing API cannot create apps; create it in AppGallery Connect, then rerun this action.")
        end
        if app_ids.length > 1
          UI.user_error!("Multiple AppGallery Connect apps matched #{params[:package_name]} (#{app_ids.join(', ')}); provide FL_APPGALLERY_APP_ID explicitly.")
        end

        Actions.lane_context[SharedValues::APPGALLERY_APP_ID] = app_ids.first
        app_ids.first
      end

      def self.find_app_ids(object, package_name)
        case object
        when Array
          object.flat_map { |value| find_app_ids(value, package_name) }
        when Hash
          app_id = object['appId'] || object[:appId]
          candidate_package = object['packageName'] || object[:packageName]
          matches = app_id && (candidate_package.to_s.empty? || candidate_package == package_name) ? [app_id.to_s] : []
          matches + object.values.flat_map { |value| find_app_ids(value, package_name) }
        else
          []
        end
      end
      private_class_method :find_app_ids

      def self.description
        'Resolve an existing AppGallery Connect HarmonyOS app from its package name'
      end

      def self.details
        'AppGallery Connect does not expose an API for creating apps. This action verifies that an app created in the console exists and exposes its app ID to later lane steps.'
      end

      def self.available_options
        AppgalleryOptions.common_without_app_id + [
          FastlaneCore::ConfigItem.new(key: :package_name, env_name: 'FL_APPGALLERY_PACKAGE_NAME', description: 'HarmonyOS package name to resolve', verify_block: proc { |value| UI.user_error!('No package name provided') if value.to_s.empty? }),
          FastlaneCore::ConfigItem.new(key: :package_types, env_name: 'FL_APPGALLERY_PACKAGE_TYPES', description: 'AppGallery package type filters; 7 is HarmonyOS APP', type: Array, default_value: [7])
        ]
      end

      def self.output
        [['APPGALLERY_APP_ID', 'Resolved AppGallery Connect application ID']]
      end

      def self.return_value
        'The resolved AppGallery Connect application ID'
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
