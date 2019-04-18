require "crystal/system/dir"

# Objects of class `Dir` are directory streams representing directories in the underlying file system.
# They provide a variety of ways to list directories and their contents.
#
# The directory used in these examples contains the two regular files (`config.h` and `main.rb`),
# the parent directory (`..`), and the directory itself (`.`).
#
# See also: `File`.
class Dir
  include Enumerable(String)
  include Iterable(String)

  getter path : String

  # Returns a new directory object for the named directory.
  def initialize(@path)
    @dir = Crystal::System::Dir.open(@path)
    @closed = false
  end

  # Alias for `new(path)`
  def self.open(path) : self
    new path
  end

  # Opens a directory and yields it, closing it at the end of the block.
  # Returns the value of the block.
  def self.open(path)
    dir = new path
    begin
      yield dir
    ensure
      dir.close
    end
  end

  # Calls the block once for each entry in this directory,
  # passing the filename of each entry as a parameter to the block.
  #
  # ```
  # Dir.mkdir("testdir")
  # File.write("testdir/config.h", "")
  #
  # d = Dir.new("testdir")
  # d.each { |x| puts "Got #{x}" }
  # ```
  #
  # produces:
  #
  # ```text
  # Got .
  # Got ..
  # Got config.h
  # ```
  def each : Nil
    while entry = read
      yield entry
    end
  end

  def each
    EntryIterator.new(self)
  end

  # Returns an array containing all of the filenames in the given directory.
  def entries : Array(String)
    entries = [] of String
    each do |filename|
      entries << filename
    end
    entries
  end

  # Calls the block once for each entry except for `.` and `..` in this directory,
  # passing the filename of each entry as a parameter to the block.
  #
  # ```
  # Dir.mkdir("testdir")
  # File.write("testdir/config.h", "")
  #
  # d = Dir.new("testdir")
  # d.each_child { |x| puts "Got #{x}" }
  # ```
  #
  # produces:
  #
  # ```text
  # Got config.h
  # ```
  def each_child : Nil
    excluded = {".", ".."}
    while entry = read
      yield entry unless excluded.includes?(entry)
    end
  end

  def each_child
    ChildIterator.new(self)
  end

  # Returns an array containing all of the filenames except for `.` and `..`
  # in the given directory.
  def children : Array(String)
    entries = [] of String
    each_child do |filename|
      entries << filename
    end
    entries
  end

  # Reads the next entry from dir and returns it as a string. Returns `nil` at the end of the stream.
  #
  # ```
  # d = Dir.new("testdir")
  # array = [] of String
  # while file = d.read
  #   array << file
  # end
  # array.sort # => [".", "..", "config.h"]
  # ```
  def read
    Crystal::System::Dir.next(@dir)
  end

  # Repositions this directory to the first entry.
  def rewind
    Crystal::System::Dir.rewind(@dir)
    self
  end

  # Closes the directory stream.
  def close
    return if @closed
    Crystal::System::Dir.close(@dir)
    @closed = true
  end

  # Returns the current working directory.
  def self.current : String
    Crystal::System::Dir.current
  end

  # Changes the current working directory of the process to the given string.
  def self.cd(path)
    Crystal::System::Dir.current = path
  end

  # Changes the current working directory of the process to the given string
  # and invokes the block, restoring the original working directory
  # when the block exits.
  def self.cd(path)
    old = current
    begin
      cd(path)
      yield
    ensure
      cd(old)
    end
  end

  # Returns the tmp dir used for tempfile.
  #
  # ```
  # Dir.tempdir # => "/tmp"
  # ```
  def self.tempdir : String
    Crystal::System::Dir.tempdir
  end

  # See `#each`.
  def self.each(dirname)
    Dir.open(dirname) do |dir|
      dir.each do |filename|
        yield filename
      end
    end
  end

  # See `#entries`.
  def self.entries(dirname) : Array(String)
    Dir.open(dirname) do |dir|
      return dir.entries
    end
  end

  # See `#each_child`.
  def self.each_child(dirname)
    Dir.open(dirname) do |dir|
      dir.each_child do |filename|
        yield filename
      end
    end
  end

  # See `#children`.
  def self.children(dirname) : Array(String)
    Dir.open(dirname) do |dir|
      return dir.children
    end
  end

  # Returns `true` if the given path exists and is a directory
  def self.exists?(path) : Bool
    if info = File.info?(path)
      info.type.directory?
    else
      false
    end
  end

  # Returns `true` if the directory at *path* is empty, otherwise returns `false`.
  # Raises `Errno` if the directory at *path* does not exist.
  #
  # ```
  # Dir.mkdir("bar")
  # Dir.empty?("bar") # => true
  # File.write("bar/a_file", "The content")
  # Dir.empty?("bar") # => false
  # ```
  def self.empty?(path) : Bool
    each_child(path) do |f|
      return false
    end
    true
  rescue ex : Errno
    raise Errno.new("Error determining size of '#{path}'", ex.errno)
  end

  # Creates a new directory at the given path. The linux-style permission mode
  # can be specified, with a default of 777 (0o777).
  #
  # NOTE: *mode* is ignored on windows.
  def self.mkdir(path, mode = 0o777)
    Crystal::System::Dir.create(path, mode)
  end

  # Creates a new directory at the given path, including any non-existing
  # intermediate directories. The linux-style permission mode can be specified,
  # with a default of 777 (0o777).
  def self.mkdir_p(path, mode = 0o777)
    return 0 if Dir.exists?(path)

    components = path.split(File::SEPARATOR)
    case components.first
    when ""
      components.shift
      subpath = "/"
    when "."
      subpath = components.shift
    else
      subpath = "."
    end

    components.each do |component|
      subpath = File.join subpath, component

      mkdir(subpath, mode) unless Dir.exists?(subpath)
    end

    0
  end

  # Removes the directory at the given path.
  def self.rmdir(path)
    Crystal::System::Dir.delete(path)
  end

  def to_s(io : IO) : Nil
    io << "#<Dir:" << @path << '>'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def pretty_print(pp)
    pp.text inspect
  end

  private struct EntryIterator
    include Iterator(String)

    def initialize(@dir : Dir)
    end

    def next
      @dir.read || stop
    end
  end

  private struct ChildIterator
    include Iterator(String)

    def initialize(@dir : Dir)
    end

    def next
      excluded = {".", ".."}
      while entry = @dir.read
        return entry unless excluded.includes?(entry)
      end
      stop
    end
  end
end

require "./dir/*"
