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

    it 'uploads an asset using the signed OBS request returned by AppGallery Connect' do
      directory = Dir.mktmpdir
      asset_path = File.join(directory, 'store icon.png')
      File.binwrite(asset_path, 'asset')
      sha256 = Digest::SHA256.file(asset_path).hexdigest
      upload_info = {
        objectId: 'CN/object.png',
        url: 'https://obs.example.test/CN/object.png',
        method: 'PUT',
        headers: { 'Authorization' => 'OBS signature', 'x-amz-content-sha256' => sha256, 'Content-Type' => 'application/octet-stream' }
      }
      url_request = stub_request(:get, "https://connect-api.cloud.huawei.com/api/publish/v2/upload-url/for-obs?appId=app&fileName=store%20icon.png&sha256=#{sha256}&contentLength=5").
                    to_return(status: 200, body: { urlInfo: upload_info }.to_json)
      upload_request = stub_request(:put, 'https://obs.example.test/CN/object.png').
                       with(headers: { 'Authorization' => 'OBS signature', 'x-amz-content-sha256' => sha256 }, body: 'asset').
                       to_return(status: 200, body: '')
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.upload_asset('app', asset_path)).to eq(JSON.parse(upload_info.to_json))
      expect(url_request).to have_been_requested.once
      expect(upload_request).to have_been_requested.once
    ensure
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
    end

    it 'associates uploaded store assets through the v3 file information endpoint' do
      file_info = { 'screenShotList' => [{ 'lang' => 'en-US', 'fileInfoList' => [{ 'deviceType' => 4, 'objectIdList' => ['CN/screenshot.png'], 'showType' => 0 }] }] }
      request = stub_request(:put, 'https://connect-api.cloud.huawei.com/api/publish/v3/app-file-info?appId=app&releaseType=1&releasePhase=0').
                with(body: file_info.to_json).
                to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.update_app_file_info('app', file_info, release_type: 1, release_phase: 0)).to eq('ret' => { 'code' => 0 })
      expect(request).to have_been_requested.once
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

    it 'queries v3 package compile status for multiple package IDs' do
      request = stub_request(:get, 'https://connect-api.cloud.huawei.com/api/publish/v3/package/compile/status?appId=app&pkgIds=one%2Ctwo').
                with(headers: { 'Authorization' => 'Bearer supplied-token', 'Client-Id' => 'client' }).
                to_return(status: 200, body: { ret: { code: 0 }, pkgStateList: [] }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.package_compile_status('app', ['one', 'two'])).to eq('ret' => { 'code' => 0 }, 'pkgStateList' => [])
      expect(request).to have_been_requested.once
    end

    it 'submits a HarmonyOS release through the v3 endpoint' do
      release_info = { 'releaseType' => 1, 'releasePhase' => 3, 'phasedReleaseDescription' => 'Controlled rollout' }
      request = stub_request(:post, 'https://connect-api.cloud.huawei.com/api/publish/v3/app-submit?appId=app').
                with(headers: { 'Authorization' => 'Bearer supplied-token', 'Client-Id' => 'client' }, body: release_info.to_json).
                to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.submit('app', release_info: release_info)).to eq('ret' => { 'code' => 0 })
      expect(request).to have_been_requested.once
    end

    it 'updates basic and localized HarmonyOS metadata through current publishing endpoints' do
      basic_request = stub_request(:put, 'https://connect-api.cloud.huawei.com/api/publish/v3/app-info?appId=app').
                      with(body: { privacyPolicy: 'https://example.test/privacy' }.to_json).
                      to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      language_request = stub_request(:put, 'https://connect-api.cloud.huawei.com/api/publish/v3/app-language-info?appId=app&releaseType=1&releasePhase=0').
                         with(body: { lang: 'en-US', appName: 'Demo' }.to_json).
                         to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      delete_request = stub_request(:delete, 'https://connect-api.cloud.huawei.com/api/publish/v2/app-language-info?appId=app&lang=fr-FR&releaseType=1').
                       to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.update_app_info('app', 'privacyPolicy' => 'https://example.test/privacy')).to eq('ret' => { 'code' => 0 })
      expect(client.update_language_info('app', { 'lang' => 'en-US', 'appName' => 'Demo' }, release_type: 1, release_phase: 0)).to eq('ret' => { 'code' => 0 })
      expect(client.delete_language_info('app', 'fr-FR', release_type: 1)).to eq('ret' => { 'code' => 0 })
      expect(basic_request).to have_been_requested.once
      expect(language_request).to have_been_requested.once
      expect(delete_request).to have_been_requested.once
    end

    it 'updates phased release settings with the app ID header' do
      body = { 'versionId' => 'version', 'releasePhase' => 3, 'state' => 'SUSPEND', 'phaseDay' => 4 }
      request = stub_request(:put, 'https://connect-api.cloud.huawei.com/api/publish/v2/version/phased-release').
                with(headers: { 'Appid' => 'app', 'Authorization' => 'Bearer supplied-token', 'Client-Id' => 'client' }, body: body.to_json).
                to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      result = client.update_phased_release('app', version_id: 'version', release_phase: 3, state: 'SUSPEND', phase_day: 4)
      expect(result).to eq('ret' => { 'code' => 0 })
      expect(request).to have_been_requested.once
    end

    it 'cancels review through the v3 endpoint with a version ID' do
      request = stub_request(:put, 'https://connect-api.cloud.huawei.com/api/publish/v3/version/on-shelf/cancel').
                with(
                  headers: { 'Appid' => 'app', 'Authorization' => 'Bearer supplied-token', 'Client-Id' => 'client' },
                  body: { versionId: 'version' }.to_json
                ).
                to_return(status: 200, body: { ret: { code: 0 } }.to_json)
      client = described_class.new(access_token: 'supplied-token', client_id: 'client')

      expect(client.cancel_review('app', 'version')).to eq('ret' => { 'code' => 0 })
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

  describe Fastlane::Actions::UploadAppgalleryAssetAction do
    it 'uploads an asset and exposes its AppGallery object ID' do
      directory = Dir.mktmpdir
      asset_path = File.join(directory, 'icon.png')
      FileUtils.touch(asset_path)
      upload_info = { 'objectId' => 'CN/icon.png', 'url' => 'https://obs.example.test/CN/icon.png', 'headers' => {} }
      client = instance_double(Fastlane::Helper::AppgalleryClient, upload_asset: upload_info)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', asset_path: asset_path, chinese_mainland_flag: nil)

      expect(client).to have_received(:upload_asset).with('app', asset_path, chinese_mainland_flag: nil)
      expect(result).to eq('CN/icon.png')
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_ASSET_OBJECT_ID]).to eq('CN/icon.png')
    ensure
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
    end
  end

  describe Fastlane::Actions::UpdateAppgalleryFileInfoAction do
    it 'associates localized assets and stores the response' do
      file_info = { 'appIconList' => [] }
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, update_app_file_info: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', file_info: file_info, release_type: 1, release_phase: 0)

      expect(client).to have_received(:update_app_file_info).with('app', file_info, release_type: 1, release_phase: 0)
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_FILE_INFO_RESPONSE]).to eq(response)
    end
  end

  describe Fastlane::Actions::SubmitToAppgalleryAction do
    it 'submits a release only through the dedicated action' do
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, submit: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', api_base: 'https://api.example.test', access_token: 'token', client_id: 'client', release_time: nil, remark: nil, release_type: 1, release_phase: 0, phased_release_description: nil)

      expect(client).to have_received(:submit).with('app', release_info: { 'releaseType' => 1, 'releasePhase' => 0 })
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_SUBMIT_RESPONSE]).to eq(response)
    end
  end

  describe Fastlane::Actions::UpdateAppgalleryPhasedReleaseAction do
    it 'updates phased release controls and stores the response' do
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, update_phased_release: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', version_id: 'version', release_phase: 3, state: 'RELEASE', description: 'rollout', phase_day: 5)

      expect(client).to have_received(:update_phased_release).with('app', version_id: 'version', release_phase: 3, state: 'RELEASE', description: 'rollout', phase_day: 5)
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_PHASED_RELEASE_RESPONSE]).to eq(response)
    end
  end

  describe Fastlane::Actions::CancelAppgalleryReviewAction do
    it 'cancels review for the selected version and stores the response' do
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, cancel_review: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', version_id: 'version')

      expect(client).to have_received(:cancel_review).with('app', 'version')
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_CANCEL_REVIEW_RESPONSE]).to eq(response)
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

  describe Fastlane::Actions::WaitForAppgalleryPackageProcessingAction do
    it 'polls until every package is ready' do
      processing = { 'pkgStateList' => [{ 'pkgId' => 'package', 'successStatus' => 1 }] }
      ready = { 'pkgStateList' => [{ 'pkgId' => 'package', 'successStatus' => 0 }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient)
      allow(client).to receive(:package_compile_status).and_return(processing, ready)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)
      allow(described_class).to receive(:sleep)

      result = described_class.run(app_id: 'app', package_ids: ['package'], interval: 1, timeout: 30)

      expect(result).to eq(ready)
      expect(client).to have_received(:package_compile_status).twice
      expect(described_class).to have_received(:sleep).with(1).once
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_PACKAGE_STATES]).to eq(ready)
    end

    it 'fails immediately when AppGallery reports a package processing failure' do
      failed = { 'pkgStateList' => [{ 'pkgId' => 'broken', 'successStatus' => 2 }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, package_compile_status: failed)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect do
        described_class.run(app_id: 'app', package_ids: ['broken'], interval: 1, timeout: 30)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /broken/)
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

  describe Fastlane::Actions::EnsureAppgalleryAppAction do
    it 'resolves one existing HarmonyOS app and stores its ID' do
      response = { 'data' => [{ 'packageName' => 'com.example.demo', 'appId' => '123' }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, app_ids: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(package_name: 'com.example.demo', package_types: [7])

      expect(client).to have_received(:app_ids).with(['com.example.demo'], package_types: [7])
      expect(result).to eq('123')
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_APP_ID]).to eq('123')
    end

    it 'explains that missing apps must be created in AppGallery Connect' do
      client = instance_double(Fastlane::Helper::AppgalleryClient, app_ids: { 'data' => [] })
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect do
        described_class.run(package_name: 'com.example.missing', package_types: [7])
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Publishing API cannot create apps/)
    end

    it 'rejects ambiguous app ID responses' do
      response = { 'data' => [{ 'appId' => '123' }, { 'appId' => '456' }] }
      client = instance_double(Fastlane::Helper::AppgalleryClient, app_ids: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      expect do
        described_class.run(package_name: 'com.example.demo', package_types: [7])
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Multiple AppGallery Connect apps/)
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

  describe Fastlane::Actions::UpdateAppgalleryLanguageInfoAction do
    it 'updates localized metadata and stores the response' do
      language_info = { 'lang' => 'en-US', 'appName' => 'Demo' }
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, update_language_info: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', language_info: language_info, release_type: 1, release_phase: 0)

      expect(client).to have_received(:update_language_info).with('app', language_info, release_type: 1, release_phase: 0)
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_LANGUAGE_INFO_RESPONSE]).to eq(response)
    end
  end

  describe Fastlane::Actions::DeleteAppgalleryLanguageInfoAction do
    it 'deletes non-default localized metadata and stores the response' do
      response = { 'ret' => { 'code' => 0 } }
      client = instance_double(Fastlane::Helper::AppgalleryClient, delete_language_info: response)
      allow(Fastlane::Helper::AppgalleryClient).to receive(:new).and_return(client)

      result = described_class.run(app_id: 'app', lang: 'fr-FR', release_type: 1)

      expect(client).to have_received(:delete_language_info).with('app', 'fr-FR', release_type: 1)
      expect(result).to eq(response)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::APPGALLERY_DELETE_LANGUAGE_RESPONSE]).to eq(response)
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
