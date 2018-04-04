# :nodoc:
module Crystal::System::Dir
  # Returns a new handle to an iterator of entries inside *path*.
  # def self.open(path : String) : Handle

  # Return the next directory entry in the iterator represented by *handle*, or
  # `nil` if iteration is complete.
  # def self.next(handle : Handle) : String?

  # Rewinds the iterator to the beginning of the directory.
  # def self.rewind(handle : Handle) : Nil

  # Closes *handle*, freeing it's resources.
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

{% if flag?(:unix) %}
  require "./unix/dir"
{% else %}
  {% raise "No implementation of Crystal::System::Dir available" %}
{% end %}
