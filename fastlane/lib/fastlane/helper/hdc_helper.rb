require 'shellwords'

module Fastlane
  module Helper
    class HdcDevice
      attr_accessor :serial

      def initialize(serial: nil)
        self.serial = serial
      end
    end

    class HdcHelper
      attr_accessor :hdc_path
      attr_accessor :devices

      def initialize(hdc_path: nil)
        candidate = hdc_path || 'hdc'
        candidate = File.expand_path(candidate) if candidate.include?(File::SEPARATOR)
        self.hdc_path = Helper.get_executable_path(candidate)
      end

      def trigger(command: nil, serial: nil)
        target = serial.to_s.empty? ? nil : "-t #{serial.shellescape}"
        Action.sh([hdc_path.shellescape, target, command].compact.join(' ').strip)
      end

      def load_all_devices
        output = Actions.sh([hdc_path.shellescape, 'list targets'].join(' '), log: false)
        self.devices = output.split("\n").map(&:strip).reject { |line| line.empty? || line.start_with?('[') }.map { |serial| HdcDevice.new(serial: serial) }
      end
    end
  end
end
