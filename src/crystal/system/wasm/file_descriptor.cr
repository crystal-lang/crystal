require "../unix/file_descriptor"

# :nodoc:
module Crystal::System::FileDescriptor
  def self.from_stdio(fd)
    return IO::FileDescriptor.new(fd).tap(&.flush_on_newline=(true))
  end
end
