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
    # continuing when ready. Otherwise returns immediately.
    #
    # Returns the number of bytes written (up to `slice.size`).
    abstract def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32

    # Closes the file descriptor resource.
    abstract def close(file_descriptor : Crystal::System::FileDescriptor) : Nil

    # Removes the file descriptor from the event loop. Can be used to free up
    # memory resources associated with the file descriptor, as well as removing
    # the file descriptor from kernel data structures.
    #
    # Called by `::IO::FileDescriptor#finalize` before closing the file
    # descriptor. Errors shall be silently ignored.
    abstract def remove(file_descriptor : Crystal::System::FileDescriptor) : Nil
  end
end
