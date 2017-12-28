struct Crystal::System::DirHandle
  # Creates a new `DirHandle`
  # def self.new(path : String) : DirHandle

  # Reads the next entry from dir and returns it as a string. Returns `nil` at the end of the stream.
  # def read

  # Repositions this directory to the first entry.
  # def rewind

  # Closes the directory stream.
  # def close

  # Returns the current working directory.
  # def self.current : String

  # Changes the current working directory of the process to the given string.
  # def self.cd(path : String)

  # Returns `true` if the given path exists and is a directory
  # def self.exists?(path : String) : Bool

  # Creates a new directory at the given path, including any non-existing
  # intermediate directories. The linux-style permission mode can be specified.
  # def self.mkdir(path : String, mode)

  # Removes the directory at the given path.
  # def self.rmdir(path : String)
end

{% if flag?(:win32) %}
  require "./windows/dir_handle"
{% else %}
  require "./unix/dir_handle"
{% end %}
