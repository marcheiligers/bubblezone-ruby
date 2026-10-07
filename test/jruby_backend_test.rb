# frozen_string_literal: true

require_relative "test_helper"

if RUBY_ENGINE == "jruby"
  class JRubyBackendTest < Minitest::Test
    def test_loads_shared_library_backend
      assert File.file?(Bubblezone::Native.library_path)
      assert_match(/upstream v\d+\.\d+\.\d+/, Bubblezone.version)
    end

    def test_preserves_native_argument_checks
      manager = Bubblezone::Manager.new

      assert_raises(TypeError) { manager.mark(nil, "text") }
      assert_raises(ArgumentError) { manager.mark("bad\0id", "text") }

      layout = Bubblezone.mark("zone", "text")
      scan_and_wait(layout)
      zone = Bubblezone.get("zone")

      assert_raises(TypeError) { zone.in_bounds?(nil, 0) }
    end

    def test_zone_info_cannot_be_constructed
      refute_respond_to Bubblezone::ZoneInfo, :new
      assert_raises(TypeError) { Bubblezone::ZoneInfo.allocate }
    end
  end
end
