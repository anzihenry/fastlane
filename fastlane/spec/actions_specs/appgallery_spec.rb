describe Fastlane do
  describe Fastlane::Actions::UploadToAppgalleryAction do
    it 'uses the HAP produced by Hvigor when no package path is passed' do
      package = File.join(Dir.mktmpdir, 'entry.hap')
      FileUtils.touch(package)
      Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_HAP_OUTPUT_PATH] = package
      client = instance_double(Fastlane::Helper::AppgalleryClient, upload_file: instance_double(Net::HTTPOK, body: 'ok'), submit: nil)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(upload_url: 'https://upload.example.test/package', package_path: nil, api_base: 'https://api.example.test', access_token: nil, client_id: nil, app_id: nil, submit_for_review: false)

      expect(client).to have_received(:upload_file).with('https://upload.example.test/package', package)
      expect(result).to eq('ok')
    ensure
      FileUtils.remove_entry(File.dirname(package)) if package && File.exist?(File.dirname(package))
    end

    it 'submits only when explicitly requested' do
      package = File.join(Dir.mktmpdir, 'entry.hap')
      FileUtils.touch(package)
      client = instance_double(Fastlane::Helper::AppgalleryClient, upload_file: instance_double(Net::HTTPOK, body: 'ok'), submit: nil)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      described_class.run(upload_url: 'https://upload.example.test/package', package_path: package, api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', app_id: 'app', submit_for_review: true)

      expect(client).to have_received(:submit).with('app')
    ensure
      FileUtils.remove_entry(File.dirname(package)) if package && File.exist?(File.dirname(package))
    end

    it 'obtains an upload URL and updates file information when requested' do
      package = File.join(Dir.mktmpdir, 'entry.hap')
      FileUtils.touch(package)
      file_info = { 'fileType' => 5, 'files' => [{ 'fileName' => 'entry.hap' }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, upload_url: 'https://upload.example.test/generated', upload_file: instance_double(Net::HTTPOK, body: 'ok'), update_app_file_info: {})
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      described_class.run(upload_url: nil, package_path: package, api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', app_id: 'app', file_info: file_info, submit_for_review: false)

      expect(client).to have_received(:upload_url).with('app', 'hap')
      expect(client).to have_received(:upload_file).with('https://upload.example.test/generated', package)
      expect(client).to have_received(:update_app_file_info).with('app', file_info)
    ensure
      FileUtils.remove_entry(File.dirname(package)) if package && File.exist?(File.dirname(package))
    end
  end

  describe Fastlane::Actions::SubmitToAppgalleryAction do
    it 'submits a release only through the dedicated action' do
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, submit: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', api_base: 'https://api.example.test', access_token: 'token', client_id: 'client')

      expect(client).to have_received(:submit).with('app')
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_SUBMIT_RESPONSE]).to eq(response)
    end
  end

  describe Fastlane::Actions::GetAppgalleryVersionAction do
    it 'stores package information in lane context' do
      response = { 'data' => [{ 'versionName' => '1.0.0' }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, app_file_info: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect(described_class.run(app_id: 'app', api_base: 'https://api.example.test', access_token: 'token', client_id: 'client')).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_FILE_INFO]).to eq(response)
    end
  end

  describe Fastlane::Actions::GetAppgalleryAppInfoAction do
    it 'stores app information in lane context' do
      response = { 'data' => { 'appName' => 'Demo' } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, app_info: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect(described_class.run(app_id: 'app', api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', lang: 'en-US', release_type: nil)).to eq(response)
      expect(client).to have_received(:app_info).with('app', lang: 'en-US', release_type: nil)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_APP_INFO]).to eq(response)
    end
  end

  describe Fastlane::Actions::UpdateAppgalleryAppInfoAction do
    it 'updates only the provided application fields' do
      app_info = { 'privacyPolicy' => 'https://example.test/privacy' }
      client = instance_double(Fastlane::Helper::AppgalleryClient, update_app_info: { 'ret' => { 'code' => 0 } })
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      described_class.run(app_id: 'app', api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', app_info: app_info)

      expect(client).to have_received(:update_app_info).with('app', app_info)
    end
  end
end
