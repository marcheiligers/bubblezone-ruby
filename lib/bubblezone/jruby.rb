# frozen_string_literal: true

require "ffi"
require "rbconfig"

module Bubblezone
  module Native
    extend FFI::Library

    class << self
      def library_path
        return ENV.fetch("BUBBLEZONE_LIBRARY_PATH") if ENV.key?("BUBBLEZONE_LIBRARY_PATH")

        extension = host_os == "darwin" ? "dylib" : "so"
        File.expand_path("../../go/build/#{host_os}_#{host_arch}/libbubblezone.#{extension}", __dir__)
      end

      private

      def host_arch
        case RbConfig::CONFIG["host_cpu"]
        when /aarch64|arm64/ then "arm64"
        when /x86_64|amd64/ then "amd64"
        else RbConfig::CONFIG["host_cpu"]
        end
      end

      def host_os
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then "darwin"
        when /linux/ then "linux"
        else
          raise LoadError, "bubblezone does not support JRuby on #{RbConfig::CONFIG["host_os"]}"
        end
      end
    end

    ffi_lib library_path

    attach_function :bubblezone_free, [:pointer], :void
    attach_function :bubblezone_upstream_version, [], :pointer

    attach_function :bubblezone_new_manager, [], :ulong_long
    attach_function :bubblezone_free_manager, [:ulong_long], :void
    attach_function :bubblezone_manager_close, [:ulong_long], :void
    attach_function :bubblezone_manager_set_enabled, [:ulong_long, :int], :void
    attach_function :bubblezone_manager_enabled, [:ulong_long], :int
    attach_function :bubblezone_manager_new_prefix, [:ulong_long], :pointer
    attach_function :bubblezone_manager_mark, [:ulong_long, :string, :string], :pointer
    attach_function :bubblezone_manager_clear, [:ulong_long, :string], :void
    attach_function :bubblezone_manager_get, [:ulong_long, :string], :ulong_long
    attach_function :bubblezone_manager_scan, [:ulong_long, :string], :pointer

    attach_function :bubblezone_free_zone_info, [:ulong_long], :void
    attach_function :bubblezone_zone_info_start_x, [:ulong_long], :int
    attach_function :bubblezone_zone_info_start_y, [:ulong_long], :int
    attach_function :bubblezone_zone_info_end_x, [:ulong_long], :int
    attach_function :bubblezone_zone_info_end_y, [:ulong_long], :int
    attach_function :bubblezone_zone_info_is_zero, [:ulong_long], :int
    attach_function :bubblezone_zone_info_in_bounds, [:ulong_long, :int, :int], :int
    attach_function :bubblezone_zone_info_pos, [:ulong_long, :int, :int, :pointer, :pointer], :int

    attach_function :bubblezone_new_global, [], :void
    attach_function :bubblezone_global_close, [], :void
    attach_function :bubblezone_global_set_enabled, [:int], :void
    attach_function :bubblezone_global_enabled, [], :int
    attach_function :bubblezone_global_new_prefix, [], :pointer
    attach_function :bubblezone_global_mark, [:string, :string], :pointer
    attach_function :bubblezone_global_clear, [:string], :void
    attach_function :bubblezone_global_get, [:string], :ulong_long
    attach_function :bubblezone_global_scan, [:string], :pointer
  end

  class << self
    def new_global
      Native.bubblezone_new_global
      nil
    end

    def close
      Native.bubblezone_global_close
      nil
    end

    def enabled=(enabled)
      Native.bubblezone_global_set_enabled(enabled ? 1 : 0)
      enabled.itself
    end

    def enabled?
      Native.bubblezone_global_enabled != 0
    end

    def new_prefix
      string_from_native(Native.bubblezone_global_new_prefix)
    end

    def mark(zone_id, text)
      string_from_native(Native.bubblezone_global_mark(native_string(zone_id), native_string(text)))
    end

    def clear(zone_id)
      Native.bubblezone_global_clear(native_string(zone_id))
      nil
    end

    def get(zone_id)
      handle = Native.bubblezone_global_get(native_string(zone_id))
      ZoneInfo.__send__(:from_handle, handle) unless handle.zero?
    end

    def scan(text)
      string_from_native(Native.bubblezone_global_scan(native_string(text)))
    end

    def upstream_version
      string_from_native(Native.bubblezone_upstream_version)
    end

    def version
      format(
        "bubblezone v%<version>s (upstream %<upstream>s) [Go native extension]",
        version: VERSION,
        upstream: upstream_version
      )
    end

    private

    def native_string(value)
      raise TypeError, "wrong argument type #{value.class} (expected String)" unless value.is_a?(String)
      raise ArgumentError, "string contains null byte" if value.include?("\0")

      value
    end

    def native_integer(value)
      raise TypeError, "wrong argument type #{value.class} (expected Integer)" unless value.is_a?(Integer)

      value
    end

    def string_from_native(pointer)
      return "" if pointer.null?

      pointer.read_string.force_encoding(Encoding::UTF_8)
    ensure
      Native.bubblezone_free(pointer) if pointer && !pointer.null?
    end
  end

  class Manager
    def initialize
      @handle = Native.bubblezone_new_manager
      ObjectSpace.define_finalizer(self, self.class.__send__(:finalizer, @handle))
    end

    def close
      Native.bubblezone_manager_close(@handle)
      nil
    end

    def enabled=(enabled)
      Native.bubblezone_manager_set_enabled(@handle, enabled ? 1 : 0)
      enabled.itself
    end

    def enabled?
      Native.bubblezone_manager_enabled(@handle) != 0
    end

    def new_prefix
      Bubblezone.__send__(:string_from_native, Native.bubblezone_manager_new_prefix(@handle))
    end

    def mark(zone_id, text)
      pointer = Native.bubblezone_manager_mark(
        @handle,
        Bubblezone.__send__(:native_string, zone_id),
        Bubblezone.__send__(:native_string, text)
      )
      Bubblezone.__send__(:string_from_native, pointer)
    end

    def clear(zone_id)
      Native.bubblezone_manager_clear(@handle, Bubblezone.__send__(:native_string, zone_id))
      nil
    end

    def get(zone_id)
      handle = Native.bubblezone_manager_get(@handle, Bubblezone.__send__(:native_string, zone_id))
      ZoneInfo.__send__(:from_handle, handle) unless handle.zero?
    end

    def scan(text)
      pointer = Native.bubblezone_manager_scan(@handle, Bubblezone.__send__(:native_string, text))
      Bubblezone.__send__(:string_from_native, pointer)
    end

    class << self
      private

      def finalizer(handle)
        proc { Native.bubblezone_free_manager(handle) }
      end
    end
  end

  class ZoneInfo
    def start_x
      Native.bubblezone_zone_info_start_x(@handle)
    end

    def start_y
      Native.bubblezone_zone_info_start_y(@handle)
    end

    def end_x
      Native.bubblezone_zone_info_end_x(@handle)
    end

    def end_y
      Native.bubblezone_zone_info_end_y(@handle)
    end

    def zero?
      Native.bubblezone_zone_info_is_zero(@handle) != 0
    end

    def in_bounds?(x, y)
      Native.bubblezone_zone_info_in_bounds(@handle, native_integer(x), native_integer(y)) != 0
    end

    def pos(x, y)
      out_x = FFI::MemoryPointer.new(:int)
      out_y = FFI::MemoryPointer.new(:int)
      Native.bubblezone_zone_info_pos(@handle, native_integer(x), native_integer(y), out_x, out_y)
      [out_x.read_int, out_y.read_int]
    end

    class << self
      def allocate
        raise TypeError, "allocator undefined for Bubblezone::ZoneInfo - use Manager#get instead"
      end

      undef_method :new

      private

      def from_handle(handle)
        instance = Class.instance_method(:allocate).bind_call(self)
        instance.instance_variable_set(:@handle, handle)
        ObjectSpace.define_finalizer(instance, finalizer(handle))
        instance
      end

      def finalizer(handle)
        proc { Native.bubblezone_free_zone_info(handle) }
      end
    end

    private

    def native_integer(value)
      Bubblezone.__send__(:native_integer, value)
    end
  end
end
