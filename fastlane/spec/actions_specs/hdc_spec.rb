describe Fastlane do
  describe Fastlane::Helper::HdcHelper do
    it 'parses connected device serials from hdc output' do
      helper = described_class.new(hdc_path: 'hdc')
      allow(Fastlane::Actions).to receive(:sh).and_return("[Empty]\nserial-one\nserial-two\n")

      expect(helper.load_all_devices.map(&:serial)).to eq(%w[serial-one serial-two])
    end
  end

  describe Fastlane::Actions::CaptureHarmonyosScreenshotsAction do
    it 'creates and exposes the screenshot directory' do
      directory = Dir.mktmpdir
      output = File.join(directory, 'screenshots')
      helper = instance_double(Fastlane::Helper::HdcHelper)
      allow(Fastlane::Helper::HdcHelper).to receive(:new).and_return(helper)
      allow(helper).to receive(:trigger)

      FileUtils.mkdir_p(output)
      FileUtils.touch(File.join(output, 'screen.png'))
      expect(described_class.run(capture_command: 'shell capture {{serial}} {{output_directory}}', output_directory: output, serial: '', serials: %w[device-a device-b], screenshot_glob: '**/*.png', hdc_path: 'hdc')).to be(true)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_SCREENSHOTS_PATH]).to eq(output)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::HARMONYOS_SCREENSHOT_PATHS]).to eq([File.join(output, 'screen.png')])
      expect(helper).to have_received(:trigger).with(command: "shell capture device-a #{output}", serial: 'device-a')
      expect(helper).to have_received(:trigger).with(command: "shell capture device-b #{output}", serial: 'device-b')
    ensure
      FileUtils.remove_entry(directory) if directory && File.exist?(directory)
    end
  end
end
