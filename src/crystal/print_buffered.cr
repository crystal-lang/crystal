module Crystal
  # Prepares an error message, with an optional exception or backtrace, to an
  # in-memory buffer, before writing to an IO, usually STDERR, in a single write
  # operation.
  #
  # Avoids intermingled messages caused by multiple threads writing to a STDIO
  # in parallel. This may still happen, since writes may not be atomic when the
  # overall size is larger than PIPE_BUF, buf it should at least write 512 bytes
  # atomically.
  def self.print_buffered(message : String, *args, to io : IO, exception = nil, backtrace = nil) : Nil
    buf = buffered_message(message, *args, exception: exception, backtrace: backtrace)
    io.write(buf.to_slice)
    io.flush unless io.sync?
  end

  # Identical to `#print_buffered` but eventually calls `System.print_error(bytes)`
  # to write to stderr without going through the event loop.
  def self.print_error_buffered(message : String, *args, exception = nil, backtrace = nil) : Nil
    buf = buffered_message(message, *args, exception: exception, backtrace: backtrace)
    System.print_error(buf.to_slice)
  end

  private def self.buffered_message(message : String, *args, exception = nil, backtrace = nil)
    buf = IO::Memory.new(4096)

    if args.empty?
      buf << message
    else
      System.printf(message, *args) { |bytes| buf.write(bytes) }
    end

    if exception
      buf << ": "
      exception.inspect_with_backtrace(buf)
    else
      buf.puts
      backtrace.try(&.each { |line| buf << "  from " << line << '\n' })
    end

    buf
  end
end
