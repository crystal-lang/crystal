class Crystal::System::FileHandle
  include IO

  # Create a new `FileHandle` using the platform-specific representation of this
  # handle.
  #
  # On unix-like platforms this constructor takes an Int32 file descriptor.
  # def self.new(platform_specific) : FileHandle

  # Returns the platform-specific representation of this handle.
  #
  # On unix-like platforms this returns an Int32 file descriptor.
  # def platform_specific

  # Reads at most `slice.size` bytes from this `FileHandle` into *slice*.
  # Returns the number of bytes read.
  # def read(slice : Bytes) : Int32

  # Writes the contents of *slice* into this `FileHandle`.
  # def write(slice : Bytes) : Nil

  # Used by the scheduler to call back to the `FileHandle` once a read is ready.
  # def resume_read(timed_out : Bool = false) : Nil

  # Used by the scheduler to call back to the `FileHandle` once a write is
  # ready.
  # def resume_write(timed_out : Bool = false) : Nil

  # Returns true if this `FileHandle` has been closed.
  # def closed? : Bool

  # Closes the `FileHandle`.
  # def close : Nil

  # Returns true if the `FileHandle` uses blocking IO.
  # def blocking? : Bool

  # Sets whether this `FileHandle` uses blocking IO.
  # def blocking=(value : Bool) : Bool

  # Returns true if this `FileHandle` is closed when `Process.exec` is called.
  # def close_on_exec? : Bool

  # Sets if this `FileHandle` is closed when `Process.exec` is called.
  # def close_on_exec=(value : Bool) : Bool

  # Returns the time to wait when reading before raising an `IO::Timeout`.
  # def read_timeout : Time::Span?

  # Sets the time to wait when reading before raising an `IO::Timeout`.
  # def read_timeout=(timeout : Time::Span?) : Time::Span?

  # Returns the time to wait when writing before raising an `IO::Timeout`.
  # def write_timeout : Time::Span?

  # Sets the time to wait when writing before raising an `IO::Timeout`.
  # def write_timeout=(timeout : Time::Span?) : Time::Span?

  # Seeks to a given offset relative to either the beginning, current position,
  # or end - depending on *whence*. Returns the new position in the file
  # measured in bytes from the beginning of the file.
  # def seek(offset : Number, whence : IO::Seek = IO::Seek::Set) : Int64

  # Returns true if this `FileHandle` is a handle of a terminal device (tty).
  # TODO: rename this to `terminal?`
  # def tty? : Bool

  # Modifies this `FileHandle` to be a handle of the same resource as *other*.
  # def reopen(other : FileHandle) : FileHandle

  # Returns a `File::Stat` object containing information about the file that
  # this `FileHandle` represents.
  # def stat : File::Stat

  # Implement `IO#rewind` using `seek` for all implementations.
  def rewind
    seek(0, IO::Seek::Set)
  end
end

require "./unix/file_handle"
