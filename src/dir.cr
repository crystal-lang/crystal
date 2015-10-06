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

  fun rewinddir(dir : Dir*)
end

# Objects of class Dir are directory streams representing directories in the underlying file system.
# They provide a variety of ways to list directories and their contents. See also `File`.
#
# The directory used in these examples contains the two regular files (config.h and main.rb),
# the parent directory (..), and the directory itself (.).
class Dir
  include Enumerable(String)
  include Iterable

  getter path

  # Returns a new directory object for the named directory.
  def initialize(@path)
    @dir = LibC.opendir(@path)
    unless @dir
      raise Errno.new("Error opening directory '#{@path}'")
    end
    @closed = false
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

  def each
    EntryIterator.new(self)
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
    # readdir() returns NULL for failure and sets errno or returns NULL for EOF but leaves errno as is.  wtf.
    LibC.errno = 0
    ent = LibC.readdir(@dir)
    if ent
      String.new(ent.value.name.buffer)
    elsif LibC.errno != 0
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

  def self.working_directory
    if dir = LibC.getcwd(nil, 0)
      String.new(dir).tap { LibC.free(dir as Void*) }
    else
      raise Errno.new("getcwd")
    end
  end

  # Changes the current working directory of the process to the given string.
  def self.cd path
    if LibC.chdir(path) != 0
      raise Errno.new("Error while changing directory to #{path.inspect}")
    end
  end

  # Changes the current working directory of the process to the given string
  # and invokes the block, restoring the original working directory
  # when the block exits.
  def self.cd(path)
    old = working_directory
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
  def self.entries(dirname)
    entries = [] of String
    foreach(dirname) do |filename|
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
    special = {'*', '?', '{', '}'}
    cwd = self.working_directory
    root = "/"  # assuming Linux or OS X
    patterns.each do |ptrn|
      next if ptrn.empty?
      recursion_depth = ptrn.count(File::SEPARATOR)
      if ptrn[0] == File::SEPARATOR
        dir = root
      else
        dir = cwd
      end
      if ptrn.includes? "**"
        recursion_depth = Int32::MAX
      end

      # optimize the glob by starting with the directory
      # which is as nested as possible:
      lastidx = 0
      depth = 0
      escaped = false
      ptrn.each_char_with_index do |c, i|
        if c == '\\'
          escaped = true
          next
        elsif c == File::SEPARATOR
          depth += 1
          lastidx = i
        elsif !escaped && special.includes? c
          break
        end
        escaped = false
      end

      recursion_depth -= depth if recursion_depth != Int32::MAX
      nested_path = ptrn[0...lastidx]
      dir = File.join(dir, nested_path)
      if !nested_path.empty? && nested_path[0] == File::SEPARATOR
        nested_path = nested_path[1..-1]
      end

      regex = glob2regex(ptrn)

      scandir(dir, nested_path, regex, 0, recursion_depth) do |path|
        if ptrn[0] == File::SEPARATOR
          yield "#{File::SEPARATOR}#{path}"
        else
          yield path
        end
      end
    end
  end

  private def self.glob2regex(pattern)
    if pattern.size == 0 || pattern == File::SEPARATOR
      raise ArgumentError.new "Empty glob pattern"
    end

    # characters which are escapable by a backslash in a glob pattern;
    # Windows paths must have double backslashes:
    escapable = {'?', '{', '}', '*', ',', '\\'}
    # characters which must be escaped in a PCRE regex:
    escaped = {'$', '(', ')', '+', '.', '[', '^', '|', '/'}

    regex_pattern = String.build do |str|
      idx = 0
      nest = 0

      idx = 1 if pattern[0] == File::SEPARATOR
      size = pattern.size

      while idx < size
        char = pattern[idx]
        if char == '\\'
          if idx + 1 < size && escapable.includes?(peek = pattern[idx + 1])
            str << '\\'
            str << peek
            idx += 2
            next
          end
        elsif char == '*'
          if idx + 2 < size &&
                       pattern[idx + 1] == '*' &&
                       pattern[idx + 2] == File::SEPARATOR
            str << "(?:.*\\" << File::SEPARATOR << ")?"
            idx += 3
            next
          elsif idx + 1 < pattern.size && pattern[idx + 1] == '*'
            str << ".*"
            idx += 2
            next
          else
            str << "[^\\" << File::SEPARATOR << "]*"
          end
        elsif escaped.includes? char
          str << "\\"
          str << char
        elsif char == '?'
          str << "[^\\" << File::SEPARATOR << "]"
        elsif char == '{'
          str << "(?:"
          nest += 1
        elsif char == '}'
          str << ")"
          nest -= 1
        elsif char == ',' && nest > 0
          str << "|"
        else
          str << char
        end
        idx += 1
      end
    end
    return Regex.new("\\A#{regex_pattern}\\z")
  end

  private def self.scandir(dir_path, rel_path, regex, level, max_level)
    dir_path_stack = [dir_path]
    rel_path_stack = [rel_path]
    level_stack = [level]
    dir_stack = [] of Dir
    recurse = true
    until dir_path_stack.empty?
      if recurse
        begin
          dir = Dir.new(dir_path)
        rescue e
          dir_path_stack.pop
          rel_path_stack.pop
          level_stack.pop
          break if dir_path_stack.empty?
          dir_path = dir_path_stack.last
          rel_path = rel_path_stack.last
          level = level_stack.last
          next
        ensure
          recurse = false
        end
        dir_stack.push dir
      end
      begin
        f = dir.read if dir
      rescue e
        f = nil
      end
      if f
        fullpath = File.join dir_path, f
        if rel_path.empty?
          relpath = f
        else
          relpath = File.join rel_path, f
        end
        begin
          stat = File.stat(fullpath)
          isdir = stat.directory? && !stat.symlink?
        rescue e
          isdir = false
        end
        if isdir
          if f != "." && f != ".." && level < max_level
            dir_path_stack.push fullpath
            rel_path_stack.push relpath
            level_stack.push level + 1
            dir_path = dir_path_stack.last
            rel_path = rel_path_stack.last
            level = level_stack.last
            recurse = true
            next
          end
        else
          if level <= max_level || max_level == Int32::MAX
            yield relpath if relpath =~ regex
          end
        end
      else
        dir.close if dir
        dir_path_stack.pop
        rel_path_stack.pop
        level_stack.pop
        dir_stack.pop
        break if dir_path_stack.empty?
        dir_path = dir_path_stack.last
        rel_path = rel_path_stack.last
        level = level_stack.last
        dir = dir_stack.last
      end
    end
  end

  def self.exists?(path)
    if LibC.stat(path, out stat) != 0
      if LibC.errno == Errno::ENOENT
        return false
      else
        raise Errno.new("stat")
      end
    end
    File::Stat.new(stat).directory?
  end

  def self.mkdir(path, mode=0o777)
    if LibC.mkdir(path, mode) == -1
      raise Errno.new("Unable to create directory '#{path}'")
    end
    0
  end

  def self.mkdir_p(path, mode=0o777)
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

  # :nodoc:
  struct EntryIterator
    include Iterator(String)

    def initialize(@dir)
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

class GlobError < Exception
end
