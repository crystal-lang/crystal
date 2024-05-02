# :nodoc:
module Crystal::System::Dir
  # :nodoc:
  #
  # Information about a directory entry.
  #
  # In particular we only care about the name, whether it's a directory, and
  # whether any hidden file attributes are set to improve the performance of
  # `Dir.glob` by not having to call `File.info` on every directory entry.
  # If dir is nil, the type is unknown.
  # In the future we might change Dir's API to expose these entries
  # with more info but right now it's not necessary.
  struct Entry
    getter name : String
    getter? dir : Bool?
    getter? native_hidden : Bool
    getter? os_hidden : Bool

    def initialize(@name, @dir, @native_hidden, @os_hidden = false)
    end
  end

  # Returns a new handle to an iterator of entries inside *path*.
  # def self.open(path : String) : Handle

  # Returns the next directory entry name in the iterator represented by *handle*, or
  # `nil` if iteration is complete.
  def self.next(dir, path) : String?
    next_entry(dir, path).try &.name
  end

  # Returns the next directory entry in the iterator represented by *handle*, or
  # `nil` if iteration is complete.
  # def self.next_entry(handle : Handle) : Entry?

  # Rewinds the iterator to the beginning of the directory.
  # def self.rewind(handle : Handle) : Nil

  # Closes *handle*, freeing its resources.
  # def self.close(handle : Handle) : Nil

  # Returns the current working directory of the application.
  # def self.current : String

  # Sets the current working directory of the application.
  # def self.current=(path : String)

  # Creates a new directory at *path*. The UNIX-style directory mode *node*
  # must be applied.
  # def self.create(path : String, mode : Int32) : Nil

  # Deletes the directory at *path*.
  # def self.delete(path : String) : Nil
end

{% if flag?(:wasi) %}
  require "./wasi/dir"
{% elsif flag?(:unix) %}
  require "./unix/dir"
{% elsif flag?(:win32) %}
  require "./win32/dir"
{% else %}
  {% raise "No implementation of Crystal::System::Dir available" %}
{% end %}
