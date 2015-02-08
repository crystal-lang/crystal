lib LibC
  type Dir = Void*

  ifdef darwin
    struct DirEntry
      d_ino : Int32
      reclen : UInt16
      type : UInt8
      namelen : UInt8
      name : UInt8[1024]
    end
  elsif linux
   struct DirEntry
      d_ino : UInt64
      d_off : Int64
      reclen : UInt16
      type : UInt8
      name : UInt8[256]
    end
  end

  ifdef linux
    struct Glob
      pathc : LibC::SizeT
      pathv : UInt8**
      offs : LibC::SizeT
      flags : Int32
      dummy : UInt8[40]
    end
  elsif darwin
    struct Glob
      pathc : LibC::SizeT
      matchc : Int32
      offs : LibC::SizeT
      flags : Int32
      pathv : UInt8**
      dummy : UInt8[48]
    end
  end

  ifdef linux
    enum GlobFlags
      APPEND = 1 << 5
      BRACE  = 1 << 10
      TILDE  = 1 << 12
    end
  elsif darwin
    enum GlobFlags
      APPEND = 0x0001
      BRACE  = 0x0080
      TILDE  = 0x0800
    end
  end

  enum GlobErrors
    NOSPACE = 1
    ABORTED = 2
    NOMATCH = 3
  end

  fun getcwd(buffer : UInt8*, size : Int32) : UInt8*
  fun chdir = chdir(path : UInt8*) : Int32
  fun opendir(name : UInt8*) : Dir*
  fun closedir(dir : Dir*) : Int32

  fun mkdir(path : UInt8*, mode : LibC::ModeT) : Int32
  fun rmdir(path : UInt8*) : Int32

  ifdef darwin
    fun readdir(dir : Dir*) : DirEntry*
  elsif linux
    fun readdir = readdir64(dir : Dir*) : DirEntry*
  end

  fun glob(pattern : UInt8*, flags : GlobFlags, errfunc : (UInt8*, Int32) -> Int32, result : Glob*) : Int32
  fun globfree(result : Glob*)
end

# Objects of class Dir are directory streams representing directories in the underlying file system.
# They provide a variety of ways to list directories and their contents. See also `File`.
#
# The directory used in these examples contains the two regular files (config.h and main.rb),
# the parent directory (..), and the directory itself (.).
class Dir
  include Enumerable(String)

  getter path

  # Returns a new directory object for the named directory.
  def initialize(@path)
    @dir = LibC.opendir(@path)
    unless @dir
      raise Errno.new("Error opening directory '#{@path}'")
    end
  end

  # Alias for `new(path)`
  def self.open(path)
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
  # d.each  {|x| puts "Got #{x}" }
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

  # Reads the next entry from dir and returns it as a string. Returns nil at the end of the stream.
  #
  # ```
  # d = Dir.new("testdir")
  # d.read   #=> "."
  # d.read   #=> ".."
  # d.read   #=> "config.h"
  # ```
  def read
    ent = LibC.readdir(@dir)
    if ent
      String.new(ent.value.name.buffer)
    else
      nil
    end
  end

  # Closes the directory stream.
  def close
    LibC.closedir(@dir)
  end

  def self.working_directory
    dir = LibC.getcwd(nil, 0)
    String.new(dir).tap { LibC.free(dir as Void*) }
  end

  # Changes the current working directory of the process to the given string.
  def self.chdir path
    if LibC.chdir(path) != 0
      raise Errno.new("Error while changing directory")
    end
  end

  # Changes the current working directory of the process to the given string
  # and invokes the block, restoring the original working directory
  # when the block exists.
  def self.chdir(path)
    old = working_directory
    begin
      chdir(path)
      yield
    ensure
      chdir(old)
    end
  end

  # Alias for `chdir`.
  def self.cd path
    chdir(path)
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
  def self.entries(dirname)
    entries = [] of String
    list(dirname) do |filename|
      entries << filename
    end
    entries
  end

  def self.[](*patterns)
    glob(patterns)
  end

  def self.[](patterns : Enumerable(String))
    glob(patterns)
  end

  def self.glob(*patterns)
    glob(patterns)
  end

  def self.glob(*patterns)
    glob(patterns) do |pattern|
      yield pattern
    end
  end

  def self.glob(patterns : Enumerable(String))
    paths = [] of String
    glob(patterns) do |path|
      paths << path
    end
    paths
  end

  def self.glob(patterns : Enumerable(String))
    paths = LibC::Glob.new
    flags = LibC::GlobFlags::BRACE | LibC::GlobFlags::TILDE
    errfunc = -> (_path : UInt8*, _errno : Int32) { 0 }

    patterns.each do |pattern|
      result = LibC.glob(pattern, flags, errfunc, pointerof(paths))

      if result == LibC::GlobErrors::NOSPACE
        raise GlobError.new "Ran out of memory"
      elsif result == LibC::GlobErrors::ABORTED
        raise GlobError.new "Read error"
      end

      flags |= LibC::GlobFlags::APPEND
    end

    Slice(UInt8*).new(paths.pathv, paths.pathc.to_i32).each do |path|
      yield String.new(path)
    end

    nil
  ensure
    LibC.globfree(pointerof(paths))
  end

  def self.exists?(path)
    if LibC.stat(path, out stat) != 0
      return false
    end
    File::Stat.new(stat).directory?
  end

  def self.mkdir(path, mode=0777)
    if LibC.mkdir(path, LibC::ModeT.cast(mode)) == -1
      raise Errno.new("Unable to create directory '#{path}'")
    end
    0
  end

  def self.mkdir_p(path, mode=0777)
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

  def self.rmdir(path)
    if LibC.rmdir(path) == -1
      raise Errno.new("Unable to remove directory '#{path}'")
    end
    0
  end

  def to_s(io)
    io << "#<Dir:" << @path << ">"
  end
end

class GlobError < Exception
end
