lib C
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

  enum DirType
    UNKNOWN = 0_u8
    FIFO = 1_u8
    CHR = 2_u8
    DIR = 4_u8
    BLK = 6_u8
    REG = 8_u8
    LNK = 10_u8
    SOCK = 12_u8
    WHT = 14_u8
  end

  ifdef linux
    struct Glob
      pathc : C::SizeT
      pathv : UInt8**
      offs : C::SizeT
      flags : Int32
      dummy : UInt8[40]
    end
  elsif darwin
    struct Glob
      pathc : C::SizeT
      matchc : Int32
      offs : C::SizeT
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
  fun opendir(name : UInt8*) : Dir*
  fun closedir(dir : Dir*) : Int32

  fun mkdir(path : UInt8*, mode : C::ModeT) : Int32
  fun rmdir(path : UInt8*) : Int32

  ifdef darwin
    fun readdir(dir : Dir*) : DirEntry*
  elsif linux
    fun readdir = readdir64(dir : Dir*) : DirEntry*
  end

  fun glob(pattern : UInt8*, flags : Int32, errfunc : (UInt8*, Int32) -> Int32, result : Glob*) : Int32
  fun globfree(result : Glob*)
end

class Dir
  def self.working_directory
    dir = C.getcwd(nil, 0)
    String.new(dir).tap { C.free(dir as Void*) }
  end

  def self.list(dirname)
    dir = C.opendir(dirname)
    unless dir
      raise Errno.new("Error listing directory '#{dirname}'")
    end

    begin
      while ent = C.readdir(dir)
        yield String.new(ent.value.name.buffer), ent.value.type
      end
    ensure
      C.closedir(dir)
    end
  end

  def self.entries(dirname)
    entries = [] of String
    list(dirname) do |name, type|
      entries << name
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

  def self.glob(patterns : Enumerable(String))
    paths = [] of String
    glob(patterns) do |path|
      paths << path
    end
    paths
  end

  def self.glob(patterns : Enumerable(String))
    paths = C::Glob.new
    flags = C::GlobFlags::BRACE|C::GlobFlags::TILDE
    errfunc = -> (_path : UInt8*, _errno : Int32) { 0 }

    patterns.each do |pattern|
      result = C.glob(pattern, flags, errfunc, pointerof(paths))

      if result == C::GlobErrors::NOSPACE
        raise GlobError.new "Ran out of memory"
      elsif result == C::GlobErrors::ABORTED
        raise GlobError.new "Read error"
      end

      flags |= C::GlobFlags::APPEND
    end

    Slice(UInt8*).new(paths.pathv, paths.pathc.to_i32).each do |path|
      yield String.new(path)
    end

    nil
  ensure
    C.globfree(pointerof(paths))
  end

  def self.exists?(path)
    if C.stat(path, out stat) != 0
      return false
    end
    File::Stat.new(stat).directory?
  end

  def self.mkdir(path, mode=0777)
    if C.mkdir(path, C::ModeT.cast(mode)) == -1
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
    if C.rmdir(path) == -1
      raise Errno.new("Unable to remove directory '#{path}'")
    end
    0
  end
end

class GlobError < Exception
end
