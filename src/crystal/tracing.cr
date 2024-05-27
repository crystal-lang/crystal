module Crystal
  {% if flag?(:tracing) %}
    # :nodoc:
    module Tracing
      # IO-like object with a fixed capacity but dynamic size within the
      # buffer's capacity (i.e. `0 <= size <= N`). Stops writing to the internal
      # buffer when capacity is reached; further writes are skipped.
      struct BufferIO(N)
        getter size : Int32

        def initialize
          @buf = uninitialized UInt8[N]
          @size = 0
        end

        def write(bytes : Bytes) : Nil
          pos = @size
          remaining = N - pos
          return if remaining == 0

          n = bytes.size.clamp(..remaining)
          bytes.to_unsafe.copy_to(@buf.to_unsafe + pos, n)
          @size = pos + n
        end

        def write(string : String) : Nil
          write string.to_slice
        end

        def write(fiber : Fiber) : Nil
          write fiber.as(Void*)
          write ":"
          write fiber.name || "?"
        end

        def write(ptr : Pointer) : Nil
          write "0x"
          Crystal::System.to_int_slice(ptr.address, 16, true, 2) { |bytes| write(bytes) }
        end

        def write(int : Int::Signed) : Nil
          Crystal::System.to_int_slice(int, 10, true, 2) { |bytes| write(bytes) }
        end

        def write(uint : Int::Unsigned) : Nil
          Crystal::System.to_int_slice(uint, 10, false, 2) { |bytes| write(bytes) }
        end

        def to_slice : Bytes
          Bytes.new(@buf.to_unsafe, @size)
        end
      end

      @[Flags]
      enum Section
        Gc
        Sched
      end

      @@sections = Section::None
      @@startup_tick = 0_u64

      @[AlwaysInline]
      def self.enabled?(section : Section) : Bool
        @@sections.includes?(section)
      end

      @[AlwaysInline]
      def self.startup_tick : UInt64
        @@startup_tick
      end

      # Setups tracing, parsing the `CRYSTAL_TRACE` environment variable to
      # enable the sections to trace (`gc` and/or `sched`).
      #
      # This should be the first thing called in main, maybe even before the GC
      # itself is initialized. The function assumes neither the GC nor ENV nor
      # anything is available and musn't allocate into the GC HEAP.
      def self.init
        @@sections = Section::None
        @@startup_tick = ::Crystal::System::Time.ticks

        {% if flag?(:win32) %}
          buf = uninitialized UInt16[256]
          name = UInt16.static_array({% for chr in "CRYSTAL_TRACE".chars %}{{chr.ord}}, {% end %} 0)
          len = LibC.GetEnvironmentVariableW(name, buf, buf.size)
          debug = buf.to_slice[0...len] if len > 0
        {% else %}
          if ptr = LibC.getenv("CRYSTAL_TRACE")
            len = LibC.strlen(ptr)
            debug = Slice.new(ptr, len) if len > 0
          end
        {% end %}

        return unless debug

        each_token(debug) do |token|
          \{% begin %}
            case token
            \{% for name in Section.constants %}
              when \{{name.downcase.id.stringify}}.to_slice
                @@sections |= Section::\{{name.id}}
            \{% end %}
            end
          \{% end %}
        end
      end

      private def self.each_token(bytes, delim = ',', &)
        while e = bytes.index(delim.ord)
          yield bytes[0, e]
          bytes = bytes[(e + 1)..]
        end
        yield bytes[0..] unless bytes.size == 0
      end

      # :nodoc:
      def self.log(section : String, operation : String, time : UInt64, **metadata)
        buf = BufferIO(512).new
        buf.write section
        buf.write "."
        buf.write operation
        buf.write " "
        buf.write time

        {% unless flag?(:wasm32) %}
          # WASM doesn't have threads (and fibers aren't implemented either)
          #
          # We also start to trace *before* Thread.current and other objects have
          # been allocated, they're lazily allocated and since we trace GC.malloc we
          # must skip the objects until they're allocated (otherwise we hit infinite
          # recursion): malloc -> trace -> malloc -> trace -> ...
          thread = ::Thread.current?

          buf.write " thread="
          {% if flag?(:linux) %}
            buf.write Pointer(Void).new(thread ? thread.@system_handle : System::Thread.current_handle)
          {% else %}
            buf.write thread ? thread.@system_handle : System::Thread.current_handle
          {% end %}
          buf.write ":"
          buf.write thread.try(&.name) || "?"

          if thread && (fiber = thread.current_fiber?)
            buf.write " fiber="
            buf.write fiber
          end
        {% end %}

        metadata.each do |key, value|
          buf.write " "
          buf.write key.to_s
          buf.write "="
          buf.write value
        end

        buf.write "\n"
        System.print_error(buf.to_slice)
      end
    end

    # Formats and prints a log message to stderr. The generated message is
    # limited to 512 bytes (PIPE_BUF) after which it will be truncated. Being
    # below PIPE_BUF the message shall be written atomically to stderr,
    # avoiding interleaved or smashed traces from multiple threads.
    #
    # Windows may not have the same guarantees but the buffering should limit
    # these from happening.
    macro trace(section, operation, tick = nil, **metadata, &block)
      if ::Crystal::Tracing.enabled?(\{{section}})
        %tick = \{{tick}} || ::Crystal::System::Time.ticks
        \{% if block %}
          %ret = \{{yield}}
          %duration = ::Crystal::System::Time.ticks - %tick
          ::Crystal::Tracing.log(\{{section.id.stringify}}, \{{operation.id.stringify}}, %tick, duration: %duration, \{{metadata.double_splat}})
          %ret
        \{% else %}
          ::Crystal::Tracing.log(\{{section.id.stringify}}, \{{operation.id.stringify}}, %tick, \{{metadata.double_splat}})
          nil
        \{% end %}
      else
        \{{yield}}
      end
    end
  {% else %}
    # :nodoc:
    module Tracing
      def self.init
      end

      def self.enabled?(section)
        false
      end

      def self.log(section : String, operation : String, time : UInt64, **metadata)
      end
    end

    macro trace(section, operation, **metadata, &block)
      \{{yield}}
    end
  {% end %}
end
