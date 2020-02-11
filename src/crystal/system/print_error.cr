module Crystal::System
  # Prints directly to stderr without going through an IO.
  # This is useful for error messages from components that are required for
  # IO to work (fibers, scheduler, event_loop).
  def self.print_error(message, *args)
    {% if flag?(:unix) %}
      LibC.dprintf 2, message, *args
    {% elsif flag?(:win32) %}
      buffer = StaticArray(UInt8, 512).new(0_u8)
      len = LibC.snprintf(buffer, buffer.size, message, *args)
      LibC._write 2, buffer, len
    {% end %}
  end
end
