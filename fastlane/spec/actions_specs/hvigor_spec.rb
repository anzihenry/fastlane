describe Fastlane do
  describe Fastlane::FastFile do
    describe 'hvigor' do
      it 'runs an Hvigor task with product and build mode properties' do
        result = Fastlane::FastFile.new.parse("platform :harmonyos do
          lane :build do
            hvigor(task: 'assembleApp', product: 'default', build_mode: 'release', hvigor_path: './README.md')
          end
        end").runner.execute(:build, :harmonyos)

        expect(result).to eq("#{File.expand_path('fastlane/README.md').shellescape} --mode project -p product\\=default -p buildMode\\=release assembleApp")
      end

      it 'uses assembleApp for build_harmonyos_app' do
        result = Fastlane::FastFile.new.parse("platform :harmonyos do
          lane :build do
            build_harmonyos_app(hvigor_path: './README.md')
          end
        end").runner.execute(:build, :harmonyos)

        expect(result).to include('assembleApp')
      end

      it 'discovers HarmonyOS artifacts' do
        directory = Dir.mktmpdir
        FileUtils.mkdir_p(File.join(directory, 'entry', 'build', 'default', 'outputs'))
        %w[app.hap bundle.app library.har].each { |name| FileUtils.touch(File.join(directory, 'entry', 'build', 'default', 'outputs', name)) }

        Fastlane::Actions::HvigorAction.discover_artifacts(directory, '**/build/**/*.{hap,app,har}')

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_HAP_OUTPUT_PATH]).to end_with('app.hap')
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_APP_OUTPUT_PATH]).to end_with('bundle.app')
        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_HAR_OUTPUT_PATH]).to end_with('library.har')
      ensure
        FileUtils.remove_entry(directory) if directory && File.exist?(directory)
      end

      it 'builds the minimal HarmonyOS fixture in its project directory' do
        source = File.expand_path('../fixtures/harmonyos/minimal_app', __dir__)
        directory = Dir.mktmpdir
        FileUtils.cp_r("#{source}/.", directory)
        wrapper = File.join(directory, 'hvigorw')
        FileUtils.chmod('+x', wrapper)
        expect(Dir.chdir(directory) { system('./hvigorw', 'assembleApp') }).to be(true)

        Fastlane::FastFile.new.parse("platform :harmonyos do
          lane :build do
            build_harmonyos_app(project_dir: '#{directory}', hvigor_path: './hvigorw')
          end
        end").runner.execute(:build, :harmonyos)

        expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_HAP_OUTPUT_PATH]).to eq(File.join(directory, 'entry/build/default/outputs/default/entry-default-signed.hap'))
      ensure
        FileUtils.remove_entry(directory) if directory && File.exist?(directory)
      end
    end
  end
end
