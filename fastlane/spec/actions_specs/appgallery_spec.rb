describe Fastlane do
  describe Fastlane::Helper::AppgalleryClient do
    it 'signs Service Account credentials as a PS256 bearer JWT without a client ID header' do
      directory = Dir.mktmpdir
      credential_path = File.join(directory, 'service-account.json')
      private_key = OpenSSL::PKey::RSA.generate(2048)
      File.write(
        credential_path,
        {
          key_id: 'key-id',
          private_key: private_key.to_pem,
          sub_account: 'sub-account',
          token_uri: 'https://oauth-login.cloud.huawei.com/oauth2/v3/token'
        }.to_json
      )
      request = stub_request(:get, 'https://connect-api.cloud.huawei.com/api/publish/v2/app-info?appId=app').
                with do |http_request|
                  authorization = http_request.headers['Authorization']
                  jwt = authorization&.delete_prefix('Bearer ')
                  header_segment, payload_segment, signature_segment = jwt.to_s.split('.')
                  header = JSON.parse(Base64.urlsafe_decode64(header_segment))
                  payload = JSON.parse(Base64.urlsafe_decode64(payload_segment))
                  signature = Base64.urlsafe_decode64(signature_segment)
                  signing_input = "#{header_segment}.#{payload_segment}"

                  http_request.headers['Client-Id'].nil? &&
                    header == { 'kid' => 'key-id', 'typ' => 'JWT', 'alg' => 'PS256' } &&
                    payload['iss'] == 'sub-account' &&
                    payload['aud'] == 'https://oauth-login.cloud.huawei.com/oauth2/v3/token' &&
                    payload['exp'] - payload['iat'] == 3600 &&
                    private_key.public_key.verify_pss('SHA256', signature, signing_input, salt_length: :digest, mgf1_hash: 'SHA256')
                end.
                to_return(status: 200, body: { data: { appName: 'Demo' } }.to_json)
      client = described_class.new(service_account_key_path: credential_path)

      expect(client.app_info('app')).to eq('data' => { 'appName' => 'Demo' })
      expect(request).to have_been_requested.once
    ensure
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
    end

    it 'uses the official API base and exchanges client credentials for a reusable token' do
      token_request = stub_request(:post, 'https://connect-api.cloud.huawei.com/api/oauth2/v1/token').
                      with(
                        headers: { 'Content-Type' => 'application/json' },
                        body: {
                          grant_type: 'client_credentials',
                          client_id: 'client',
                          client_secret: 'secret'
                        }.to_json
                      ).
                      to_return(status: 200, body: { access_token: 'token', expires_in: 3600 }.to_json)
      app_info_request = stub_request(:get, 'https://connect-api.cloud.huawei.com/api/publish/v2/app-info?appId=app').
                         with(headers: { 'Authorization' => 'Bearer token', 'Client-Id' => 'client' }).
                         to_return(status: 200, body: { data: { appName: 'Demo' } }.to_json)
      client = described_class.new(client_id: 'client', client_secret: 'secret')

      2.times { expect(client.app_info('app')).to eq('data' => { 'appName' => 'Demo' }) }

      expect(token_request).to have_been_requested.once
      expect(app_info_request).to have_been_requested.twice
    end

    it 'uses a provided access token without requesting another one' do
      request = stub_request(:get, 'https://region.example.test/api/publish/v2/app-file-info?appid=app').
                with(headers: { 'Authorization' => 'Bearer supplied-token', 'Client-Id' => 'client' }).
                to_return(status: 200, body: { data: [] }.to_json)
      client = described_class.new(api_base: 'https://region.example.test/api/', access_token: 'supplied-token', client_id: 'client')

      expect(client.app_file_info('app')).to eq('data' => [])
      expect(request).to have_been_requested.once
      expect(a_request(:post, %r{/oauth2/v1/token})).not_to have_been_made
    end

    it 'queries the v3 HarmonyOS version list with the app ID header' do
      request = stub_request(:post, 'https://connect-api.cloud.huawei.com/api/publish/v3/version/brief-info/list').
                with(
                  headers: { 'Appid' => 'app', 'Authorization' => 'Bearer supplied-token', 'Client-Id' => 'client' },
                  body: { packageName: 'com.example.demo', state: '0,1' }.to_json
                ).
                to_return(status: 200, body: { ret: { code: 0 }, versionList: [] }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.versions('app', package_name: 'com.example.demo', state: [0, 1])).to eq('ret' => { 'code' => 0 }, 'versionList' => [])
      expect(request).to have_been_requested.once
    end

    it 'fails before an authenticated request when credentials are incomplete' do
      client = described_class.new(client_id: 'client')

      expect { client.app_info('app') }.to raise_error(FastlaneCore::Interface::FastlaneError, /client secret/)
    end
  end

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

  describe Fastlane::Actions::GetAppgalleryVersionsAction do
    it 'stores the version list in lane context' do
      response = { 'ret' => { 'code' => 0 }, 'versionList' => [{ 'versionId' => 'version' }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, versions: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', package_name: nil, state: [0, 1])

      expect(client).to have_received(:versions).with('app', package_name: nil, state: [0, 1])
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_VERSIONS]).to eq(response)
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

  describe Fastlane::Actions::GetAppgalleryAppIdsAction do
    it 'looks up AppGallery IDs for HarmonyOS package names' do
      response = { 'data' => [{ 'appId' => '123' }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, app_ids: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect(described_class.run(api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', package_names: ['com.example.demo'], package_types: [7])).to eq(response)
      expect(client).to have_received(:app_ids).with(['com.example.demo'], package_types: [7])
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_APP_IDS]).to eq(response)
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

  describe Fastlane::Actions::DownloadFromAppgalleryAction do
    it 'stores the downloaded package path in lane context' do
      output_path = File.join(Dir.mktmpdir, 'app.hap')
      client = instance_double(Fastlane::Helper::AppgalleryClient, download_file: output_path)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect(described_class.run(download_url: 'https://download.example.test/app.hap', output_path: output_path)).to eq(output_path)
      expect(client).to have_received(:download_file).with('https://download.example.test/app.hap', output_path)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_DOWNLOADED_PACKAGE_PATH]).to eq(output_path)
    ensure
      FileUtils.remove_entry(File.dirname(output_path)) if output_path && File.exist?(File.dirname(output_path))
    end
  end
end
