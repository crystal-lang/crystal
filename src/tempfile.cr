require "c/stdlib"
require "file_utils"

# The `Tempfile` class is for managing temporary files.
# Every tempfile is operated as a `File`, including
# initializing, reading and writing.
#
# ```
# tempfile = Tempfile.new("foo")
# # or
# tempfile = Tempfile.open("foo") do |file|
#   file.print("foobar")
# end
#
# File.size(tempfile.path)       # => 6
# File.stat(tempfile.path).mtime # => 2015-10-20 13:11:12 UTC
# File.exists?(tempfile.path)    # => true
# File.read_lines(tempfile.path) # => ["foobar"]
# ```
#
# Files created from this class are stored in a directory that handles
# temporary files.
#
# ```
# Tempfile.new("foo").path # => "/tmp/foo.ulBCPS"
# ```
#
# Also, it is encouraged to delete a tempfile after using it, which
# ensures they are not left behind in your filesystem until garbage collected.
#
# ```
# tempfile = Tempfile.new("foo")
# tempfile.unlink
# ```
#
# The optional `extension` argument can be used to force the resulting filename
# to end with the given extension.
#
# ```
# Tempfile.new("foo", ".png").path # => "/tmp/foo.ulBCPS.png"
# ```
class Tempfile < File
  # Creates a `Tempfile` with the given filename and extension.
  #
  # *encoding* and *invalid* are passed to `IO#set_encoding`.
  def initialize(name, extension = nil, encoding = nil, invalid = nil)
    fileno, path = Crystal::System::File.mktemp(name, extension)
    super(path, fileno, blocking: true, encoding: encoding, invalid: invalid)
  end

  # Retrieves the full path of a this tempfile.
  #
  # ```
  # Tempfile.new("foo").path # => "/tmp/foo.ulBCPS"
  # ```
  getter path : String

  # Returns a fully-qualified path to a temporary file without actually
  # creating the file.
  #
  # ```
  # Tempfile.tempname # => "/tmp/20171206-1234-449386"
  # ```
  #
  # The optional `extension` argument can be used to make the resulting
  # filename to end with the given extension.
  #
  # ```
  # Tempfile.tempname(".sock") # => "/tmp/20171206-1234-449386.sock"
  # ```
  def self.tempname(extension = nil)
    time = Time.now.to_s("%Y%m%d")
    rand = Random.rand(0x100000000).to_s(36)
    File.join(dirname, "#{time}-#{Process.pid}-#{rand}#{extension}")
  end

  # Yields a fully-qualified path to a temporary file to the given block and
  # ensures the path is removed at exit if it exists.
  #
  # This method is useful to ensure a temporary path is cleaned up after it has
  # been used. The path will be removed whether it is a file or directory.
  #
  # The optional `extension` argument can be used to make the resulting
  # filename to end with the given extension.
  #
  # The file will not actually be created by this method.
  #
  # ```
  # Tempfile.tempname("txt") do |temp|
  #   File.write(temp, "foo")
  #   File.read(temp) # => "foo"
  # end
  #
  # Tempfile.tempname do |temp|
  #   `git clone https://github.com/crystal-lang/crystal.git #{temp}`
  # end
  # ```
  def self.tempname(extension = nil)
    path = tempname(extension)
    yield path
  ensure
    if path && File.exists?(path)
      FileUtils.rm_r(path)
    end
  end

  # Creates a file with *filename* and *extension*, and yields it to the given
  # block. It is closed and returned at the end of this method call.
  #
  # ```
  # tempfile = Tempfile.open("foo") do |file|
  #   file.print("bar")
  # end
  # File.read(tempfile.path) # => "bar"
  # ```
  def self.open(filename, extension = nil)
    tempfile = Tempfile.new(filename, extension)
    begin
      yield tempfile
    ensure
      tempfile.close
    end
    tempfile
  end

  # Returns the tmp dir used for tempfile.
  #
  # ```
  # Tempfile.dirname # => "/tmp"
  # ```
  def self.dirname : String
    Crystal::System::File.tempdir
  end

  # Deletes this tempfile.
  def delete
    File.delete(@path)
  end

  # ditto
  def unlink
    delete
  end
end
