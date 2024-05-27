abstract class Crystal::EventLoop
  module FileDescriptor
    # Reads at least one byte from the file descriptor into *slice* and continues
    # fiber when the read is complete.
    # Returns the number of bytes read.
    abstract def read(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32

    # Writes at least one byte from *slice* to the file descriptor and continues
    # fiber when the write is complete.
    # Returns the number of bytes written.
    abstract def write(file_descriptor : Crystal::System::FileDescriptor, slice : Bytes) : Int32

    # Closes the file descriptor resource.
    abstract def close(file_descriptor : Crystal::System::FileDescriptor) : Nil
  end
end
