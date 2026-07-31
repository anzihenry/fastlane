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
  end
end
