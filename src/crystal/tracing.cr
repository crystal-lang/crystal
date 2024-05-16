module Crystal
  # IO-like object with a fixed size. Stops writing to the internal buffer
  # when capacity is reached. Any further writes are skipped.
  struct StaticIO(N)
    getter size : Int32

    def initialize
      @buf = uninitialized UInt8[N]
      @size = 0
    end

    def write(str : String) : Nil
      write str.to_slice
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

  {% if flag?(:tracing) %}
    # :nodoc:
    module Tracing
      @@gc = uninitialized Bool
      @@sched = uninitialized Bool
      @@tick = uninitialized Time::Span

      @[AlwaysInline]
      def self.tick : Time::Span
        @@tick
      end

      # Setups tracing, parsing the `CRYSTAL_TRACE` environment variable to
      # enable the sections to trace (`gc` and/or `sched`).
      #
      # This should be the first thing called in main, maybe even before the GC
      # itself is initialized. The function assumes neither the GC nor ENV nor
      # anything is available.
      def self.init
        @@gc = true
        @@sched = true
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
          if token == "gc".to_slice
            @@gc = true
          elsif token == "sched".to_slice
            @@sched = true
          end
        end
      end

      def self.enabled?(section : String) : Bool
        case section
        when "gc"
          @@gc == true
        when "sched"
          @@sched == true
        else
          false
        end
      end

      private def self.each_token(bytes, delim = ',', &)
        while e = bytes.index(delim.ord)
          yield bytes[0, e]
          bytes = bytes[(e + 1)..]
        end
        yield bytes[0..] unless bytes.size == 0
      end

      # Formats and prints a log message to STDERR. The generated message is
      # limited to 512 bytes (PIPE_BUF) after which it will be truncated.
      #
      # Doesn't use `dprintf(2)` nor `Crystal::System.print_error` that will
      # write multiple times to fd, leading to smashed log lines with
      # multithreading, we prefer to use `Crystal::System.printf` to format the
      # string into a stack allocated buffer that has a maximum size of
      # PIPE_BUF bytes.
      #
      # Eventually writes to STDERR in a single write operation, which should be
      # atomic since the buffer is lower than of equal to PIPE_BUF.
      #
      # Doesn't continue to write on partial writes (e.g. interrupted by a signal)
      # as the output could be smashed with a parallel write.
      def self.log(fmt : String, *args) : Nil
        buf = StaticIO(512).new
        Crystal::System.printf(fmt, *args) { |bytes| buf.write bytes }
        Crystal::System.print_error(buf.to_slice)
      end
    end

    # The *fmt* argument only accepts a subset of printf modifiers (namely
    # `spdux` plus the `l` and `ll` length modifiers).
    #
    # When *block* is present, measures how long the block takes then writes
    # the trace to the standard error. Otherwise immediately writes a trace to
    # the standard error.
    #
    # Prepends *fmt* with the timing (current monotonic time or duration)
    # along with thread and scheduler information (when present).
    #
    # Does nothing when tracing is disabled for the section.
    macro trace(section, action, fmt = "", *args, &block)
      if ::Crystal::Tracing.enabled?(\{{section}})
        %tick = ::Time.monotonic
        %time = %tick - ::Crystal::Tracing.tick
        \{% if block %}
          %ret = \{{yield}}
          %duration = ::Time.monotonic - %tick
          ::Crystal.trace_end(%time, %duration, \{{section}}, \{{action}}, \{{fmt}}, \{{args.splat}})
          %ret
        \{% else %}
          ::Crystal.trace_end(%time, nil, \{{section}}, \{{action}}, \{{fmt}}, \{{args.splat}})
          nil
        \{% end %}
      else
        \{{yield}}
      end
    end

    # :nodoc:
    macro trace_end(time, duration, section, action, fmt = "", *args)
      %time = (\{{time}}).total_nanoseconds.to_i64!
      %duration = (\{{duration}}).try(&.total_nanoseconds.to_i64!) || -1_i64

      {% if flag?(:wasm32) %}
        # WASM doesn't have threads (and fibers aren't implemented either)
        ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} t=%lld d=%lld \{{fmt.id}}\n",
                               %time, %duration, \{{args.splat}})
      {% else %}
        {% thread_type = flag?(:linux) ? "0x%lx".id : "%p".id %}

        # we may start to trace *before* Thread.current and other objects have
        # been allocated, they're lazily allocated and since we trace GC.malloc we
        # must skip the objects until they're allocated (otherwise we hit infinite
        # recursion): malloc -> trace -> malloc -> trace -> ...
        if %thread = Thread.current?
          if %fiber = %thread.current_fiber?
            ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} t=%lld d=%lld thread={{thread_type}} [%s] fiber=%p [%s] \{{fmt.id}}\n",
                                   %time, %duration, %thread.@system_handle, %thread.name || "?", %fiber.as(Void*), %fiber.name || "?", \{{args.splat}})
          else
            # fallback: no current fiber for the current thread (yet)
            ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} t=%lld d=%lld thread={{thread_type}} [%s] \{{fmt.id}}\n",
                                   %time, %duration, %thread.@system_handle, %thread.name || "?", \{{args.splat}})
          end
        else
          # fallback: no Thread object (yet)
          ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} t=%lld d=%lld thread={{thread_type}} [%s] \{{fmt.id}}\n",
                                 %time, %duration, Crystal::System::Thread.current_handle, "?", \{{args.splat}})
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

    macro trace(section, action, fmt = "", *args, &block)
      \{{yield}}
    end

    # :nodoc:
    macro trace_end(t, tick_or_duration, section, action, fmt = "", *args)
    end
  {% end %}
end
