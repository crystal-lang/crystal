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

        def to_slice : Bytes
          Bytes.new(@buf.to_unsafe, @size)
        end
      end

      @[Flags]
      enum Section
        Gc
        Sched
      end

      @@sections = uninitialized Section
      @@tick = uninitialized Time::Span

      @[AlwaysInline]
      def self.enabled?(section : Section) : Bool
        @@sections.includes?(section)
      end

      @[AlwaysInline]
      def self.tick : Time::Span
        @@tick
      end

      # Setups tracing, parsing the `CRYSTAL_TRACE` environment variable to
      # enable the sections to trace (`gc` and/or `sched`).
      #
      # This should be the first thing called in main, maybe even before the GC
      # itself is initialized. The function assumes neither the GC nor ENV nor
      # anything is available and musn't allocate into the GC HEAP.
      def self.init
        @@sections = Section::None
        @@tick = Time.monotonic

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
          case token
          when "gc".to_slice
            @@sections |= Section::Gc
          when "sched".to_slice
            @@sections |= Section::Sched
          end
        end
      end

      private def self.each_token(bytes, delim = ',', &)
        while e = bytes.index(delim.ord)
          yield bytes[0, e]
          bytes = bytes[(e + 1)..]
        end
        yield bytes[0..] unless bytes.size == 0
      end

      # Formats and prints a log message to stderr. The generated message is
      # limited to 512 bytes (PIPE_BUF) after which it will be truncated. Being
      # below PIPE_BUF the message shall be written atomically to stderr,
      # avoiding interleaved or smashed traces from multiple threads.
      #
      # Windows may not have the same guarantees but the buffering should limit
      # these from happening.
      def self.log(fmt : String, *args) : Nil
        buf = BufferIO(512).new
        Crystal::System.printf(fmt, *args) { |bytes| buf.write bytes }
        Crystal::System.print_error(buf.to_slice)
      end
    end

    macro trace(section, operation, fmt = "", *args, &block)
      if ::Crystal::Tracing.enabled?(\{{section}})
        %tick = ::Time.monotonic
        %time = %tick - ::Crystal::Tracing.tick
        \{% if block %}
          %ret = \{{yield}}
          %duration = ::Time.monotonic - %tick
          ::Crystal.trace_end(%time, %duration, \{{section}}, \{{operation}}, \{{fmt}}, \{{args.splat}})
          %ret
        \{% else %}
          ::Crystal.trace_end(%time, nil, \{{section}}, \{{operation}}, \{{fmt}}, \{{args.splat}})
          nil
        \{% end %}
      else
        \{{yield}}
      end
    end

    # :nodoc:
    macro trace_end(time, duration, section, operation, fmt = "", *args)
      %time = (\{{time}}).total_nanoseconds.to_i64!
      %duration = (\{{duration}}).try(&.total_nanoseconds.to_i64!) || -1_i64

      {% if flag?(:wasm32) %}
        # WASM doesn't have threads (and fibers aren't implemented either)
        ::Crystal::Tracing.log("\{{section.id}} \{{operation.id}} t=%lld d=%lld \{{fmt.id}}\n",
                               %time, %duration, \{{args.splat}})
      {% else %}
        {% thread_type = flag?(:linux) ? "0x%lx".id : "%p".id %}

        # we may start to trace *before* Thread.current and other objects have
        # been allocated, they're lazily allocated and since we trace GC.malloc we
        # must skip the objects until they're allocated (otherwise we hit infinite
        # recursion): malloc -> trace -> malloc -> trace -> ...
        if (%thread = Thread.current?) && (%fiber = %thread.current_fiber?)
          ::Crystal::Tracing.log(
            "\{{section.id}} \{{operation.id}} t=%lld d=%lld thread={{thread_type}} [%s] fiber=%p [%s] \{{fmt.id}}\n",
            %time, %duration, %thread.@system_handle, %thread.name || "?", %fiber.as(Void*), %fiber.name || "?", \{{args.splat}})
        else
          %thread_handle = %thread ? %thread.@system_handle : Crystal::System::Thread.current_handle
          ::Crystal::Tracing.log(
            "\{{section.id}} \{{operation.id}} t=%lld d=%lld thread={{thread_type}} [%s] \{{fmt.id}}\n",
            %time, %duration, %thread_handle, %thread.try(&.name) || "?", \{{args.splat}})
        end
      {% end %}
    end
  {% else %}
    # :nodoc:
    module Tracing
      def self.init
      end

      def self.enabled?(section)
        false
      end

      def self.log(fmt : String, *args)
      end
    end

    macro trace(section, operation, fmt = "", *args, &block)
      \{{yield}}
    end

    # :nodoc:
    macro trace_end(time, duration, section, operation, fmt = "", *args)
    end
  {% end %}
end
