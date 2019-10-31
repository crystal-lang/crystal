module Crystal::System
  # Prints directly to stderr without going through an IO.
  # This is useful for error messages from components that are required for
  # IO to work (fibers, scheduler, event_loop).
  def self.print_error(message)
    {% if flag?(:unix) %}
      LibC.dprintf 2, message
    {% elsif flag?(:win32) %}
      LibC._write 2, message, message.bytesize
    {% end %}
  end
end
