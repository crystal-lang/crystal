abstract class Crystal::EventLoop
  module FileDescriptor
    # Reads at least one byte from the file descriptor into *slice*.
    #
    # Blocks the current fiber if no data is available for reading, continuing
    # when available. Otherwise returns immediately.
    #
    # Returns the number of bytes read (up to `slice.size`).
    # Returns 0 when EOF is reached.
    abstract def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32

    # Writes at least one byte from *slice* to the file descriptor.
    #
    # Blocks the current fiber if the file descriptor isn't ready for writing,
    # continuing when it is. Otherwise returns immediately.
    #
    # Returns the number of bytes written (up to `slice.size`).
    abstract def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32

    # Closes the file descriptor resource.
    abstract def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
  end
end
