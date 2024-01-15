module Crystal
  {% if flag?(:tracing) %}
    # :nodoc:
    module Tracing
      # Setups tracing, parsing the CRYSTAL_TRACE environment variable to enable
      # the sections to trace (`gc` and/or `sched`).
      #
      # This should be the first thing called in main, maybe even before the GC
      # itself is initialized. The function assumes neither the GC nor ENV nor
      # anything is available.
      def self.init
        @@gc = false
        @@sched = false

        {% if flag?(:win32) %}
          buf = uninitialized UInt8[256]
          len = LibC.GetEnvironmentVariableW("CRYSTAL_TRACE", buf, buf.size)
          debug = buf.to_slice(len) if len > 0
        {% else %}
          if ptr = LibC.getenv("CRYSTAL_TRACE")
            len = LibC.strlen(ptr)
            debug = Slice.new(ptr, len) if len > 0
          end
        {% end %}

        return unless debug

        each_token(debug) do |token|
          @@gc = true if token == "gc".to_slice
          @@sched = true if token == "sched".to_slice
        end
      end

      def self.enabled?(section : String) : Bool
        case section
        when "gc"
          !!@@gc
        when "sched"
          !!@@sched
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
      # limited to 511 bytes after which it will be truncated.
      #
      # Doesn't use `dprintf(2)` that may do multiple writes to fd, leading to
      # smashed log lines with multithreading, we prefer to use `snprintf(2)` with
      # a stack allocated buffer that has a maximum size of PIPE_BUF bytes minus
      # one byte for the terminating null byte (targets such as linux have a
      # pipe buf of 4096 but I chose a conservative number that should be large
      # enough).
      #
      # Eventually writes to STDERR in a single write operation, this should be
      # atomic since the buffer is smaller than of equal to PIPE_BUF (on POSIX
      # platforms at least).
      #
      # Doesn't continue to write on partial writes (e.g. interrupted by a signal)
      # as the output could be smashed with a parallel write.
      def self.log(format : String, *args) : Nil
        buffer = uninitialized UInt8[512]

        len = LibC.snprintf(buffer, buffer.size, format, *args)
        return if len == 0

        {% if flag?(:win32) %}
          # FIXME: atomicity of _write on win32?
          LibC._write(2, buffer, len)
        {% else %}
          LibC.write(2, buffer, len)
        {% end %}
      end
    end

    macro trace(section, action, format = "", *args, &block)
      if ::Crystal::Tracing.enabled?(\{{section}})
        \{% if block %}
          %start = ::Time.monotonic
          %ret = \{{yield}}
          %stop = ::Time.monotonic
          ::Crystal.trace_end('d', %stop - %start, \{{section}}, \{{action}}, \{{format}}, \{{args.splat}})
          %ret
        \{% else %}
          %tick = ::Time.monotonic
          ::Crystal.trace_end('t', %tick, \{{section}}, \{{action}}, \{{format}}, \{{args.splat}})
          nil
        \{% end %}
      else
        \{{yield}}
      end
    end

    macro trace_end(t, tick_or_duration, section, action, format = "", *args)
      # we may start to trace _before_ Thread.current and other objects have
      # been allocated, they're lazily allocated and since we trace GC.malloc we
      # must skip the objects until they are allocate (otherwise we hit infinite
      # recursion): malloc -> trace -> malloc -> trace -> ...
      if %thread = Thread.current?
        if %scheduler = %thread.scheduler?
          %fiber = %scheduler.@current
          ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} \{{t.id}}=%.9f thread=%lx fiber=%lx [%s] \{{format.id}}\n",
                                 (\{{tick_or_duration}}).to_f, %thread, %fiber.object_id, %fiber.name || "", \{{args.splat}})
        else
          # fallback: no scheduler (or not started yet?) for the current thread
          ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} \{{t.id}}=%.9f thread=%lx \{{format.id}}\n",
                                 (\{{tick_or_duration}}).to_f, %thread, \{{args.splat}})
        end
      else
        # fallback: no Thread object (yet)
        ::Crystal::Tracing.log("\{{section.id}} \{{action.id}} \{{t.id}}=%.9f thread=%lx \{{format.id}}\n",
                               (\{{tick_or_duration}}).to_f, Crystal::System::Thread.current_handle, \{{args.splat}})
      end
    end
  {% else %}
    module Tracing
      def self.enabled?(section)
        false
      end

      def self.log(format : String, *args)
      end
    end

    macro trace(section, action, format = "", *args, &block)
      \{{yield}}
    end

    macro trace_end(t, tick_or_duration, section, action, format = "", *args)
    end
  {% end %}
end
