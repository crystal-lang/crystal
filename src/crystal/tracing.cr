module Crystal
  {% if flag?(:tracing) %}
    # Formats and prints a log message to STDERR. The generated message is
    # limited to 511 bytes after which it will be truncated.
    #
    # Doesn't use `dprintf(2)` that may do multiple writes to fd, leading to
    # smashed log lines with multithreading, we prefer to use `snprintf(2)` with
    # a stack allocated buffer that has a maximum size of PIPE_BUF bytes minus
    # one byte for the terminating null byte.
    #
    # Eventually writes to STDERR in a single write operation that should be
    # atomic since the buffer is smaller than of equal to PIPE_BUF, on POSIX
    # platforms at least.
    #
    # Doesn't continue to write on partial writes (e.g. interrupted by a signal)
    # as the output could be smashed with a parallel write.
    def self.trace_log(format : String, *args) : Nil
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

    macro trace(section, action, format = "", *args, &block)
      \{% if block %}
        %start = ::Crystal::System::Time.monotonic
        %ret = \{{yield}}
        %stop = ::Crystal::System::Time.monotonic
        %duration = { %stop[0] - %start[0], %stop[1] - %start[1] }
        ::Crystal.trace_end('d', %duration, \{{section}}, \{{action}}, \{{format}}, \{{args.splat}})
        %ret
      \{% else %}
        %tick = ::Crystal::System::Time.monotonic
        ::Crystal.trace_end('t', %tick, \{{section}}, \{{action}}, \{{format}}, \{{args.splat}})
        nil
      \{% end %}
    end

    macro trace_end(t, tick_or_duration, section, action, format = "", *args)
      %s, %ns = \{{tick_or_duration}}

      # we may start to trace _before_ Thread.current and other objects have
      # been allocated, they're lazily allocated and since we trace GC.malloc we
      # must skip the objects until they are allocate (otherwise we hit infinite
      # recursion): malloc -> trace -> malloc -> trace -> ...
      if %thread = Thread.current?
        if %scheduler = %thread.scheduler?
          %fiber = %scheduler.@current
          ::Crystal.trace_log("\{{section.id}} \{{action.id}} \{{t.id}}=%d.%09d thread=%lx fiber=%lx [%s] \{{format.id}}\n",
                              %s, %ns, %thread, %fiber.object_id, %fiber.name || "", \{{args.splat}})
        else
          # fallback: no scheduler (or not started yet?) for the current thread
          ::Crystal.trace_log("\{{section.id}} \{{action.id}} \{{t.id}}=%d.%09d thread=%lx \{{format.id}}\n",
                              %s, %ns, %thread, \{{args.splat}})
        end
      else
        # fallback: no Thread object (yet)
        ::Crystal.trace_log("\{{section.id}} \{{action.id}} \{{t.id}}=%d.%09d thread=%lx \{{format.id}}\n",
                            %s, %ns, Crystal::System::Thread.current_handle, \{{args.splat}})
      end
    end
  {% else %}
    def self.trace_log(format : String, *args)
    end

    macro trace(section, action, format = "", *args, &block)
      \{{yield}}
    end

    macro trace_end(t, tick_or_duration, section, action, format = "", *args)
    end
  {% end %}
end
