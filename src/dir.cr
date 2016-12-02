require "c/dirent"
require "c/unistd"
require "c/sys/stat"

# Objects of class Dir are directory streams representing directories in the underlying file system.
# They provide a variety of ways to list directories and their contents. See also `File`.
#
# The directory used in these examples contains the two regular files (config.h and main.rb),
# the parent directory (..), and the directory itself (.).
class Dir
  include Enumerable(String)
  include Iterable(String)

  getter path : String

  # Returns a new directory object for the named directory.
  def initialize(@path)
    @dir = LibC.opendir(@path.check_no_null_byte)
    unless @dir
      raise Errno.new("Error opening directory '#{@path}'")
    end
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
  # Got main.rb
  # ```
  def each
    while entry = read
      yield entry
    end
  end

  def each
    EntryIterator.new(self)
  end

  # Reads the next entry from dir and returns it as a string. Returns nil at the end of the stream.
  #
  # ```
  # d = Dir.new("testdir")
  # d.read # => "."
  # d.read # => ".."
  # d.read # => "config.h"
  # ```
  def read
    # readdir() returns NULL for failure and sets errno or returns NULL for EOF but leaves errno as is.  wtf.
    Errno.value = 0
    ent = LibC.readdir(@dir)
    if ent
      String.new(ent.value.d_name.to_unsafe)
    elsif Errno.value != 0
      raise Errno.new("readdir")
    else
      nil
    end
  end

  # Repositions this directory to the first entry.
  def rewind
    LibC.rewinddir(@dir)
    self
  end

  # Closes the directory stream.
  def close
    return if @closed
    if LibC.closedir(@dir) != 0
      raise Errno.new("closedir")
    end
    @closed = true
  end

  # Returns the current working directory.
  def self.current : String
    if dir = LibC.getcwd(nil, 0)
      String.new(dir).tap { LibC.free(dir.as(Void*)) }
    else
      raise Errno.new("getcwd")
    end
  end

  # Changes the current working directory of the process to the given string.
  def self.cd(path)
    if LibC.chdir(path.check_no_null_byte) != 0
      raise Errno.new("Error while changing directory to #{path.inspect}")
    end
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

  # Calls the block once for each entry in the named directory,
  # passing the filename of each entry as a parameter to the block.
  def self.foreach(dirname)
    Dir.open(dirname) do |dir|
      dir.each do |filename|
        yield filename
      end
    end
  end

  # Returns an array containing all of the filenames in the given directory.
  def self.entries(dirname) : Array(String)
    entries = [] of String
    foreach(dirname) do |filename|
      entries << filename
    end
    entries
  end

  # Returns true if the given path exists and is a directory
  def self.exists?(path) : Bool
    if LibC.stat(path.check_no_null_byte, out stat) != 0
      if Errno.value == Errno::ENOENT || Errno.value == Errno::ENOTDIR
        return false
      else
        raise Errno.new("stat")
      end
    end
    File::Stat.new(stat).directory?
  end

  # Creates a new directory at the given path. The linux-style permission mode
  # can be specified, with a default of 777 (0o777).
  def self.mkdir(path, mode = 0o777)
    if LibC.mkdir(path.check_no_null_byte, mode) == -1
      raise Errno.new("Unable to create directory '#{path}'")
    end
    0
  end

  # Creates a new directory at the given path, including any non-existing
  # intermediate directories. The linux-style permission mode can be specified,
  # with a default of 777 (0o777).
  def self.mkdir_p(path, mode = 0o777)
    return 0 if Dir.exists?(path)

    components = path.split(File::SEPARATOR)
    if components.first == "." || components.first == ""
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
    if LibC.rmdir(path.check_no_null_byte) == -1
      raise Errno.new("Unable to remove directory '#{path}'")
    end
    0
  end

  def to_s(io)
    io << "#<Dir:" << @path << ">"
  end

  def inspect(io)
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

    def rewind
      @dir.rewind
      self
    end
  end
end

require "./dir/*"
