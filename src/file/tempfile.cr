class File
  # Returns a fully-qualified path to a temporary file.
  # The file is not actually created on the file system.
  #
  # ```
  # File.tempname("foo", ".sock") # => "/tmp/foo20171206-1234-449386.sock"
  # ```
  #
  # *prefix* and *suffix* are appended to the front and end of the file name, respectively.
  # These values may contain directory separators.
  #
  # The path will be placed in *dir* which defaults to the standard temporary directory `Dir.tempdir`.
  def self.tempname(prefix : String?, suffix : String?, *, dir : String = Dir.tempdir)
    name = String.build do |io|
      if prefix
        io << prefix
        io << '-'
      end

      io << Time.now.to_s("%Y%m%d")
      io << '-'

      {% unless flag?(:win32) %}
        # TODO: Remove this once Process is implemented
        io << Process.pid
        io << '-'
      {% end %}

      io << Random.rand(0x100000000).to_s(36)

      io << suffix
    end

    File.join(dir, name)
  end

  # Returns a fully-qualified path to a temporary file.
  # The optional *suffix* is appended to the file name.
  #
  # ```
  # File.tempname          # => "/tmp/20171206-1234-449386"
  # File.tempname(".sock") # => "/tmp/20171206-1234-449386.sock"
  # ```
  def self.tempname(suffix : String? = nil, *, dir : String = Dir.tempdir)
    tempname(prefix: nil, suffix: suffix, dir: dir)
  end

  # Creates a temporary file.
  #
  # ```
  # tempfile = File.tempfile("foo", ".bar")
  # tempfile.delete
  # ```
  #
  # *prefix* and *suffix* are appended to the front and end of the file name, respectively.
  # These values may contain directory separators.
  #
  # The file will be placed in *dir* which defaults to the standard temporary directory `Dir.tempdir`.
  #
  # *encoding* and *invalid* are passed to `IO#set_encoding`.
  #
  # It is the caller's responsibility to remove the file when no longer needed.
  def self.tempfile(prefix : String?, suffix : String?, *, dir : String = Dir.tempdir, encoding = nil, invalid = nil)
    fileno, path = Crystal::System::File.mktemp(prefix, suffix, dir)
    new(path, fileno, blocking: true, encoding: encoding, invalid: invalid)
  end

  # Creates a temporary file.
  #
  # ```
  # tempfile = File.tempfile(".bar")
  # tempfile.delete
  # ```
  #
  # *prefix* and *suffix* are appended to the front and end of the file name, respectively.
  # These values may contain directory separators.
  #
  # The file will be placed in *dir* which defaults to the standard temporary directory `Dir.tempdir`.
  #
  # *encoding* and *invalid* are passed to `IO#set_encoding`.
  #
  # It is the caller's responsibility to remove the file when no longer needed.
  def self.tempfile(suffix : String? = nil, *, dir : String = Dir.tempdir, encoding = nil, invalid = nil)
    tempfile(prefix: nil, suffix: suffix, dir: dir, encoding: encoding, invalid: invalid)
  end

  # Creates a temporary file and yields it to the given block. It is closed and returned at the end of this method call.
  #
  # ```
  # tempfile = File.tempfile("foo", ".bar") do |file|
  #   file.print("bar")
  # end
  # File.read(tempfile.path) # => "bar"
  # tempfile.delete
  # ```
  #
  # *prefix* and *suffix* are appended to the front and end of the file name, respectively.
  # These values may contain directory separators.
  #
  # The file will be placed in *dir* which defaults to the standard temporary directory `Dir.tempdir`.
  #
  # *encoding* and *invalid* are passed to `IO#set_encoding`.
  #
  # It is the caller's responsibility to remove the file when no longer needed.
  def self.tempfile(prefix : String?, suffix : String?, *, dir : String = Dir.tempdir, encoding = nil, invalid = nil)
    tempfile = tempfile(prefix: prefix, suffix: suffix, dir: dir, encoding: encoding, invalid: invalid)
    begin
      yield tempfile
    ensure
      tempfile.close
    end
    tempfile
  end

  # Creates a temporary file and yields it to the given block. It is closed and returned at the end of this method call.
  #
  # ```
  # tempfile = File.tempfile(".bar") do |file|
  #   file.print("bar")
  # end
  # File.read(tempfile.path) # => "bar"
  # tempfile.delete
  # ```
  #
  # *prefix* and *suffix* are appended to the front and end of the file name, respectively.
  # These values may contain directory separators.
  #
  # The file will be placed in *dir* which defaults to the standard temporary directory `Dir.tempdir`.
  #
  # *encoding* and *invalid* are passed to `IO#set_encoding`.
  #
  # It is the caller's responsibility to remove the file when no longer needed.
  def self.tempfile(suffix : String? = nil, *, dir : String = Dir.tempdir, encoding = nil, invalid = nil)
    tempfile(prefix: nil, suffix: suffix, dir: dir, encoding: encoding, invalid: invalid) do |tempfile|
      yield tempfile
    end
  end
end
