describe Fastlane::SetupHarmonyos do
  it 'generates HarmonyOS build and test lanes' do
    setup = described_class.new
    setup.platform = :harmonyos
    setup.is_swift_fastfile = false
    setup.fastfile_content = setup.fastfile_template_content.gsub(':ios', ':harmonyos')
    setup.appfile_content = setup.appfile_template_content

    setup.append_lane(['lane :build do', '  build_harmonyos_app', 'end'])
    setup.append_lane(['lane :test do', '  hvigor(task: "test")', 'end'])

    expect(setup.fastfile_content).to include('platform :harmonyos')
    expect(setup.fastfile_content).to include('build_harmonyos_app')
    expect(setup.appfile_content).to include('HarmonyOS project settings')
  end
end
