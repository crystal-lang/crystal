# A `Path` represents a filesystem path and allows path-handling operations
# such as querying its components as well as semantic manipulations.
#
# A path is hierarchical and composed of a sequence of directory and file name
# elements separated by a special separator or delimiter. A root component,
# that identifies a file system hierarchy, may also be present.
# The name element that is farthest from the root of the directory hierarchy is
# the name of a file or directory. The other name elements are directory names.
# A `Path` can represent a root, a root and a sequence of names, or simply one or
# more name elements.
# A `Path` is considered to be an empty path if it consists solely of one name
# element that is empty. Accessing a file using an empty path is equivalent
# to accessing the default directory of the process.
#
# # Examples
#
# ```
# Path["foo/bar/baz.cr"].parent   # => Path["foo/bar"]
# Path["foo/bar/baz.cr"].basename # => "baz.cr"
# Path["./foo/../bar"].normalize  # => Path["bar"]
# Path["~/bin"].expand            # => Path["/home/crystal/bin"]
# ```
#
# For now, its methods are purely lexical, there is no direct filesystem access.
#
# Path handling comes in different kinds depending on operating system:
#
# * `Path.posix()` creates a new POSIX path
# * `Path.windows()` creates a new Windows path
# * `Path.new()` means `Path.posix` on POSIX platforms and `Path.windows()`
#    on Windows platforms.
#
# ```
# # On POSIX system:
# Path.new("foo", "bar", "baz.cr") == Path.posix("foo/bar/baz.cr")
# # On Windows system:
# Path.new("foo", "bar", "baz.cr") == Path.windows("foo\\bar\\baz.cr")
# ```
#
# The main differences between Windows and POSIX paths:
# * POSIX paths use forward slash (`/`) as only path separator, Windows paths use
#   backslash (`\`) as default separator but also recognize forward slashes.
# * POSIX paths are generally case-sensitive, Windows paths case-insensitive
#   (see `#<=>`).
# * A POSIX path is absolute if it begins with a forward slash (`/`). A Windows path
#   is absolute if it starts with a drive letter and root (`C:\`).
#
# ```
# Path.posix("/foo/./bar").normalize   # => Path.posix("/foo/bar")
# Path.windows("/foo/./bar").normalize # => Path.windows("\\foo\\bar")
#
# Path.posix("/foo").absolute?   # => true
# Path.windows("/foo").absolute? # => false
#
# Path.posix("foo") == Path.posix("FOO")     # => false
# Path.windows("foo") == Path.windows("FOO") # => true
# ```
struct Path
  include Comparable(Path)

  class Error < Exception
  end

  enum Kind : UInt8
    # TODO: Consider adding NATIVE member, see https://github.com/crystal-lang/crystal/pull/5635#issuecomment-441237811

    POSIX
    WINDOWS

    def self.native : Kind
      {% if flag?(:win32) %}
        WINDOWS
      {% else %}
        POSIX
      {% end %}
    end
  end

  # The file/directory separator characters of the current platform.
  # `{'/'}` on POSIX, `{'\\', '/'}` on Windows.
  SEPARATORS = separators(Kind.native)

  # :nodoc:
  def self.separators(kind)
    if kind.windows?
      {'\\', '/'}
    else
      {'/'}
    end
  end

  # Creates a new `Path` of native kind.
  #
  # When compiling for a windows target, this is equal to `Path.windows()`,
  # otherwise `Path.posix` is used.
  def self.new(name : String = "") : Path
    new(name.check_no_null_byte, Kind.native)
  end

  # ditto
  def self.new(name : String, *parts) : Path
    new(name).join(*parts)
  end

  # ditto
  def self.[](name : String, *parts) : Path
    new(name, *parts)
  end

  # ditto
  def self.new(parts : Enumerable) : Path
    new("").join(parts)
  end

  # ditto
  def self.[](parts : Enumerable) : Path
    new(parts)
  end

  # Creates a new `Path` of POSIX kind.
  def self.posix(name : String = "") : Path
    new(name.check_no_null_byte, Kind::POSIX)
  end

  # ditto
  def self.posix(name : String, *parts) : Path
    posix(name).join(parts)
  end

  # ditto
  def self.posix(parts : Enumerable) : Path
    posix("").join(parts)
  end

  # Creates a new `Path` of Windows kind.
  def self.windows(name : String = "") : Path
    new(name.check_no_null_byte, Kind::WINDOWS)
  end

  # ditto
  def self.windows(name : String, *parts) : Path
    windows(name).join(parts)
  end

  # ditto
  def self.windows(parts : Enumerable) : Path
    windows("").join(parts)
  end

  # :nodoc:
  protected def initialize(@name : String, @kind : Kind)
  end

  # Internal helper method to create a new `Path` of the same kind as `self`.
  private def new_instance(string : String, kind = @kind) : Path
    Path.new(string, kind)
  end

  # Returns `true` if this is a Windows path.
  def windows? : Bool
    @kind.windows?
  end

  # Returns `true` if this is a POSIX path.
  def posix? : Bool
    @kind.posix?
  end

  # Returns `true` if this is a native path for the target platform.
  def native? : Bool
    @kind == Kind.native
  end

  # Returns all components of this path except the last one.
  #
  # ```
  # Path["/foo/bar/file.cr"].dirname # => "/foo/bar"
  # ```
  def dirname : String
    reader = Char::Reader.new(at_end: @name)
    separators = self.separators

    # skip trailing separators
    while separators.includes?(reader.current_char) && reader.pos > 0
      reader.previous_char
    end

    # skip last component
    while !separators.includes?(reader.current_char) && reader.pos > 0
      reader.previous_char
    end

    # strip trailing separators
    while separators.includes?(reader.current_char) && reader.pos > 0
      reader.previous_char
    end

    if reader.pos == 0
      current = reader.current_char

      if separators.includes?(current)
        return current.to_s
      else
        # skip windows here for next condition regarding anchor
        if windows? && reader.has_next? && reader.peek_next_char == ':'
          reader.next_char
        else
          return "."
        end
      end
    end

    if windows? && reader.current_char == ':' && reader.pos == 1 && (anchor = self.anchor)
      return anchor.to_s
    end

    @name.byte_slice(0, reader.pos + 1)
  end

  # Returns the parent path of this path.
  #
  # If the path is empty or `"."`, it returns `"."`. If the path is rooted
  # and in the top-most hierarchy, the root path is returned.
  #
  # ```
  # Path["foo/bar/file.cr"].parent # => Path["foo/bar"]
  # Path["foo"].parent             # => Path["."]
  # Path["/foo"].parent            # => Path["/"]
  # Path["/"].parent               # => Path["/"]
  # Path[""].parent                # => Path["."]
  # Path["foo/bar/."].parent       # => Path["foo/bar"]
  # ```
  def parent : Path
    new_instance dirname
  end

  # Returns all parent paths of this path beginning with the topmost path.
  #
  # ```
  # Path["foo/bar/file.cr"].parents # => [Path["."], Path["foo"], Path["foo/bar"]]
  # ```
  def parents : Array(Path)
    parents = [] of Path
    each_parent do |parent|
      parents << parent
    end
    parents
  end

  # Yields each parent of this path beginning with the topmost parent.
  #
  # ```
  # Path["foo/bar/file.cr"].each_parent { |parent| puts parent }
  # # Path["."]
  # # Path["foo"]
  # # Path["foo/bar"]
  # ```
  def each_parent(&block : Path ->)
    return if @name.empty? || @name == "."

    first = true
    each_part_separator_index do |pos|
      if pos == 0 || (pos == 2 && @name[1] == ':')
        first = false
        break if pos == @name.bytesize - 1 || @name.byte_slice(pos + 1).each_char.all? { |char| separators.includes?(char) || char == '.' }
        path = anchor || new_instance(separators[0].to_s)
      else
        if first && @name[0] != '.'
          yield new_instance "."
        end
        first = false

        break if pos == @name.bytesize - 1
        path = new_instance @name.byte_slice(0, pos)
      end

      yield path
    end

    if first
      # this path didn't contain any separators
      yield new_instance "."
    end
  end

  # Returns the last component of this path.
  #
  # If *suffix* is given, it is stripped from the end.
  #
  # ```
  # Path["/foo/bar/file.cr"].basename # => "file.cr"
  # Path["/foo/bar/"].basename        # => "bar"
  # Path["/"].basename                # => "/"
  # Path[""].basename                 # => ""
  # ```
  def basename(suffix : String? = nil) : String
    suffix.try &.check_no_null_byte

    return "" if @name.empty?
    return @name if @name.size == 1 && separators.includes?(@name[0])

    bytes = @name.to_slice

    current = bytes.size - 1

    separators = self.separators.map &.ord

    # skip trailing separators
    while separators.includes?(bytes[current]) && current > 0
      current -= 1
    end

    # read suffix
    if suffix && suffix.bytesize < current && suffix == @name.byte_slice(current - suffix.bytesize + 1, suffix.bytesize)
      current -= suffix.bytesize
    end

    end_pos = {current, 1}.max

    # read basename
    while !separators.includes?(bytes[current]) && current > 0
      current -= 1
    end

    start_pos = current + 1

    if start_pos == 1 && !separators.includes?(bytes[current])
      start_pos = 0
    end

    @name.byte_slice(start_pos, end_pos - start_pos + 1)
  end

  # Returns the extension of this path, or an empty string if it has no extension.
  #
  # ```
  # Path["foo.cr"].extension # => ".cr"
  # Path["foo"].extension    # => ""
  # ```
  def extension : String
    bytes = @name.to_slice

    return "" if bytes.empty?

    current = bytes.size - 1

    # if the pattern is `foo.`, it has no extension
    return "" if bytes[current] == '.'.ord

    separators = self.separators.map &.ord

    # position the reader at the last `.` or SEPARATOR
    # that is not the first char
    while !separators.includes?(bytes[current]) &&
          bytes[current] != '.'.ord &&
          current > 0
      current -= 1
    end

    # if we are the beginning of the string there is no extension
    # `/foo` and `.foo` have no extension
    return "" unless current > 0

    # otherwise we are not at the beginning, and there is a previous char.
    # if current is '/', then the pattern is prefix/foo and has no extension
    return "" if separators.includes?(bytes[current])

    # otherwise the current_char is '.'
    # if previous is '/', then the pattern is `prefix/.foo`  and has no extension
    return "" if separators.includes?(bytes[current - 1])

    # So the current char is '.',
    # we are not at the beginning,
    # the previous char is not a '/',
    # and we have an extension
    String.new(bytes[current, bytes.size - current])
  end

  # Removes redundant elements from this path and returns the shortest equivalent path by purely lexical processing.
  # It applies the following rules iteratively until no further processing can be done:
  #
  #   1. Replace multiple slashes with a single slash.
  #   2. Eliminate each `.` path name element (the current directory).
  #   3. Eliminate each `..` path name element (the parent directory) preceded
  #      by a non-`..` element along with the latter.
  #   4. Eliminate `..` elements that begin a rooted path:
  #      that is, replace `"/.."` by `"/"` at the beginning of a path.
  #
  # If the path turns to be empty, the current directory (`"."`) is returned.
  #
  # The returned path ends in a slash only if it is the root (`"/"`, `\`, or `C:\`).
  #
  # See also Rob Pike: *[Lexical File Names in Plan 9 or Getting Dot-Dot Right](https://9p.io/sys/doc/lexnames.html)*
  def normalize(*, remove_final_separator : Bool = true) : Path
    return new_instance "." if @name.empty?

    drive, root = drive_and_root
    reader = Char::Reader.new(@name)
    dotdot = 0
    separators = self.separators
    add_separator_at_end = !remove_final_separator && ends_with_separator?

    new_name = String.build do |str|
      if drive
        str << drive.gsub('/', '\\')
        reader.pos += drive.bytesize
      end
      if root
        str << separators[0]
        reader.next_char
        dotdot = str.bytesize
      end
      anchor_pos = str.bytesize

      while (char = reader.current_char) != Char::ZERO
        curr_pos = reader.pos
        if separators.includes?(char)
          # empty path element
          reader.next_char
        elsif char == '.' && (reader.pos + 1 == @name.bytesize || separators.includes?(reader.peek_next_char))
          # . element
          reader.next_char
        elsif char == '.' && reader.next_char == '.' && (reader.pos + 1 == @name.bytesize || separators.includes?(reader.peek_next_char))
          # .. element: remove to last /
          reader.next_char
          if str.bytesize > dotdot
            str.back 1
            while str.bytesize > dotdot && !separators.includes?((str.buffer + str.bytesize).value.unsafe_chr)
              str.back 1
            end
          elsif !root
            if str.bytesize > 0
              str << separators[0]
            end
            str << ".."
            dotdot = str.bytesize
          end
        else
          reader.pos = curr_pos # make sure to reset lookahead used in previous condition

          # real path element
          # add slash if needed
          if str.bytesize > anchor_pos && !separators.includes?((str.buffer + str.bytesize - 1).value.unsafe_chr)
            str << separators[0]
          end

          loop do
            str << char
            char = reader.next_char
            break if separators.includes?(char) || char == Char::ZERO
          end
        end
      end

      if str.empty?
        str << '.'
      end

      last_char = (str.buffer + str.bytesize - 1).value.unsafe_chr

      if add_separator_at_end && !separators.includes?(last_char)
        str << separators[0]
      end
    end

    new_instance new_name
  end

  # Yields each component of this path as a `String`.
  def each_part
    last_pos = 0
    each_part_separator_index do |pos|
      yield @name.byte_slice(last_pos, pos - last_pos)
      last_pos = pos
    end
  end

  # Returns the components of this path as an `Array(String)`.
  def parts : Array(String)
    parts = [] of String
    each_part do |part|
      parts << part
    end
    parts
  end

  private def each_part_separator_index
    reader = Char::Reader.new(@name)
    last_was_separator = false
    reader.each do |char|
      if separators.includes?(char)
        yield reader.pos unless last_was_separator
        last_was_separator = true
      else
        last_was_separator = false
      end
    end
  end

  # Converts this path to a Windows path.
  #
  # ```
  # Path.posix("foo/bar").to_windows   # => Path.windows("foo/bar")
  # Path.windows("foo/bar").to_windows # => Path.windows("foo/bar")
  # ```
  #
  # This creates a new instance with the same string representation but with
  # `Kind::WINDOWS`.
  def to_windows : Path
    new_instance(@name, Kind::WINDOWS)
  end

  # Converts this path to a POSIX path.
  #
  # ```
  # Path.windows("foo/bar\\baz").to_posix # => Path.posix("foo/bar/baz")
  # Path.posix("foo/bar").to_posix        # => Path.posix("foo/bar")
  # Path.posix("foo/bar\\baz").to_posix   # => Path.posix("foo/bar\\baz")
  # ```
  #
  # It returns a copy of this instance if it already has POSIX kind. Otherwise
  # a new instance is created with `Kind::POSIX` and all occurences of
  # backslash file separators (`\\`) replaced by forward slash (`/`).
  def to_posix : Path
    if posix?
      new_instance(@name, Kind::POSIX)
    else
      new_instance(@name.gsub(Path.separators(Kind::WINDOWS)[0], Path.separators(Kind::POSIX)[0]), Kind::POSIX)
    end
  end

  # Converts this path to the given *kind*.
  #
  # See `#to_windows` and `#to_posix` for details.
  def to_kind(kind)
    if kind.posix?
      to_posix
    else
      to_windows
    end
  end

  # Converts this path to an absolute path. Relative paths are
  # referenced from the current working directory of the process (`Dir.current`)
  # unless *base* is given, in which case it will be used as the reference path.
  #
  # ```
  # Path["foo"].expand             # => Path["/current/path/foo"]
  # Path["~/crystal/foo"].expand   # => Path["/home/crystal/foo"]
  # Path["baz"].expand("/foo/bar") # => Path["/foo/bar/baz"]
  # ```
  #
  # *home* specifies the home directory which `~` will expand to.
  # If *expand_base* is `true`, *base* itself will be exanded in `Dir.current`
  # if it is not an absolute path. This guarantees the method returns an absolute
  # path (assuming that `Dir.current` is absolute).
  def expand(base : Path | String = Dir.current, *, home = Path.home, expand_base = true) : Path
    base = Path.new(base) unless base.is_a?(Path)
    base = base.to_kind(@kind)
    if base == self
      # expanding base, avoid recursion
      return new_instance(@name).normalize(remove_final_separator: false)
    end

    name = @name

    if name == "~"
      name = home.to_kind(@kind).normalize.to_s
    elsif name.starts_with?("~/")
      name = home.to_kind(@kind).normalize.join(name.byte_slice(2, name.bytesize - 2)).to_s
    end

    unless new_instance(name).absolute?
      unless base.absolute? || !expand_base
        base = base.expand
      end

      if name.empty?
        expanded = base
      elsif windows?
        base_drive, base_root = base.drive_and_root
        drive, root = new_instance(name).drive_and_root

        if drive && base_root
          base_relative = base_drive ? base.@name.lchop(base_drive) : base.@name
          expanded = "#{drive}#{base_relative}#{separators[0]}#{name.lchop(drive)}"
        elsif root
          if base_drive
            expanded = "#{base_drive}#{name}"
          else
            expanded = name
          end
        else
          if base_root
            expanded = base.join(name)
          else
            expanded = String.build do |io|
              if drive
                io << drive
              elsif base_drive
                io << base_drive
              end
              base_relative = base.@name
              base_relative = base_relative.lchop(base_drive) if base_drive
              name_relative = drive ? name.lchop(drive) : name

              io << base_relative
              io << separators[0] unless base_relative.empty?
              io << name_relative
            end
          end
        end
      else
        expanded = base.join(name)
      end
    else
      expanded = name
    end

    expanded = new_instance(expanded) unless expanded.is_a?(Path)
    expanded.normalize(remove_final_separator: false)
  end

  # Appends the given *parts* to this path and returns the joined path.
  #
  # ```
  # Path["foo"].join("bar", "baz")       # => Path["foo/bar/baz"]
  # Path["foo/"].join("/bar/", "/baz")   # => Path["foo/bar/baz"]
  # Path["/foo/"].join("/bar/", "/baz/") # => Path["/foo/bar/baz/"]
  # ```
  def join(*parts) : Path
    join parts
  end

  # Appends the given *parts* to this path and returns the joined path.
  #
  # ```
  # Path["foo"].join("bar", "baz")           # => Path["foo/bar/baz"]
  # Path["foo/"].join(Path["/bar/", "/baz"]) # => Path["foo/bar/baz"]
  # Path["/foo/"].join("/bar/", "/baz/")     # => Path["/foo/bar/baz/"]
  # ```
  #
  # Non-matching paths are implicitly converted to this path's kind.
  #
  # ```
  # Path.posix("foo/bar").join(Path.windows("baz\\baq")) # => Path.posix("foo/bar/baz/baq")
  # Path.windows("foo\\bar").join(Path.posix("baz/baq")) # => Path.windows("foo\\bar\\baz/baq")
  # ```
  def join(parts : Enumerable) : Path
    new_name = String.build do |str|
      str << @name
      last_ended_with_separator = ends_with_separator?

      parts.each_with_index do |part, index|
        case part
        when Path
          # Every POSIX path is also a valid Windows path, so we only need to
          # convert the other way around (see `#to_windows`, `#to_posix`).
          part = part.to_posix if posix? && part.windows?

          part = part.@name
        else
          part = part.to_s
          part.check_no_null_byte
        end

        if part.empty?
          if index == parts.size - 1
            str << separators[0] unless last_ended_with_separator
            last_ended_with_separator = true
          else
            last_ended_with_separator = false
          end

          next
        end

        byte_start = 0
        byte_count = part.bytesize

        case {starts_with_separator?(part), last_ended_with_separator}
        when {true, true}
          byte_start += 1
          byte_count -= 1
        when {false, false}
          str << separators[0] unless str.bytesize == 0
        end

        last_ended_with_separator = ends_with_separator?(part)

        str.write part.unsafe_byte_slice(byte_start, byte_count)
      end
    end

    new_instance new_name
  end

  # Appends the given *part* to this path and returns the joined path.
  #
  # ```
  # Path["foo"] / "bar" / "baz"     # => Path["foo/bar/baz"]
  # Path["foo/"] / Path["/bar/baz"] # => Path["foo/bar/baz"]
  # ```
  def /(part : Path | String) : Path
    join(part)
  end

  # Resolves path *name* in this path's parent directory.
  #
  # Raises `Path::Error` if `#parent` is `nil`.
  def sibling(name : Path | String) : Path?
    if parent = self.parent
      parent.join(name)
    else
      raise Error.new("Can't resolve sibling for a path without parent directory")
    end
  end

  # Compares this path to *other*.
  #
  # The comparison is performed strictly lexically: `foo` and `./foo` are *not*
  # treated as equal. To compare paths semantically, they need to be normalized
  # and converted to the same kind.
  #
  # ```
  # Path["foo"] <=> Path["foo"]               # => 0
  # Path["foo"] <=> Path["./foo"]             # => 1
  # Path.posix("foo") <=> Path.windows("foo") # => -1
  # ```
  #
  # Comparison is case-sensitive for POSIX paths and case-insensitive for
  # Windows paths.
  #
  # ```
  # Path.posix("foo") <=> Path.posix("FOO")     # => 1
  # Path.windows("foo") <=> Path.windows("FOO") # => 0
  # ```
  def <=>(other : Path)
    ord = @name.compare(other.@name, case_insensitive: windows?)
    return ord if ord != 0

    @kind <=> other.@kind
  end

  # Returns a path representing the drive component or `nil` if this path does not contain a drive.
  #
  # See `#anchor` for the combination of drive and `#root`.
  #
  # ```
  # Path.windows("C:\\Program Files").drive       # => Path.windows("C:")
  # Path.windows("\\\\host\\share\\folder").drive # => Path.windows("\\\\host\\share")
  # ```
  #
  # NOTE: Drives are only available for Windows paths. It can either be a drive letter (`C:`) or a UNC share (`\\host\share`).
  def drive : Path?
    if drive = drive_and_root[0]
      new_instance drive
    end
  end

  # Returns the root path component of this path or `nil` if it is not rooted.
  #
  # See `#anchor` for the combination of `#drive` and root.
  #
  # ```
  # Path["/etc/"].root                           # => Path["/"]
  # Path.windows("C:Program Files").root         # => nil
  # Path.windows("C:\\Program Files").root       # => Path.windows("\\")
  # Path.windows("\\\\host\\share\\folder").root # => Path.windows("\\")
  # ```
  def root : Path?
    if root = drive_and_root[1]
      new_instance root
    end
  end

  # Returns the concatenation of `#drive` and `#root`.
  #
  # ```
  # Path["/etc/"].anchor                           # => Path["/"]
  # Path.windows("C:Program Files").anchor         # => Path.windows("C:")
  # Path.windows("C:\\Program Files").anchor       # => Path.windows("C:\\")
  # Path.windows("\\\\host\\share\\folder").anchor # => Path.windows("\\\\host\\share\\")
  # ```
  def anchor : Path?
    drive, root = drive_and_root

    if root
      if drive
        new_instance({drive, root}.join)
      else
        new_instance(root)
      end
    elsif drive
      new_instance drive
    end
  end

  # Returns a tuple of `#drive` and `#root` as strings.
  def drive_and_root : {String?, String?}
    if windows?
      if @name.byte_at?(1) == ':'.ord && @name.byte_at?(0).try(&.chr.ascii_letter?)
        drive = @name.byte_slice(0, 2)
        if separators.includes?(@name.byte_at?(2).try(&.chr))
          return drive, @name.byte_slice(2, 1)
        else
          return drive, nil
        end
      elsif (@name.starts_with?("\\\\") || @name.starts_with?("//")) && !separators.includes?(@name.byte_at?(2).try &.unsafe_chr)
        # UNC share
        index = 0
        last_pos = 0
        each_part_separator_index do |pos|
          if index == 2
            return @name.byte_slice(0, pos), @name.byte_slice(pos, 1)
          end
          index += 1
          last_pos = pos
        end

        if index == 2 && last_pos < @name.bytesize && !separators.includes?(@name.byte_at(last_pos + 1).unsafe_chr)
          # the entire name is a UNC share without a root
          return @name, nil
        else
          # Not a UNC share, but path starts with two separators
          return nil, @name.byte_slice(0, 1)
        end
      elsif starts_with_separator?
        return nil, @name.byte_slice(0, 1)
      else
        return nil, nil
      end
    elsif absolute? # posix
      return nil, "/"
    else
      return nil, nil
    end
  end

  # Returns `true` if this path is absolute.
  #
  # A POSIX path is absolute if it begins with a forward slash (`/`).
  # A Windows path is absolute if it begins with a drive letter and root (`C:\`)
  # or with a UNC share (`\\server\share\`).
  def absolute? : Bool
    separators = self.separators
    if windows?
      first_is_separator = false
      starts_with_double_separator = false
      found_share_name = false
      @name.each_char_with_index do |char, index|
        case index
        when 0
          if separators.includes?(char)
            first_is_separator = true
          else
            return false unless char.ascii_letter?
          end
        when 1
          if first_is_separator && separators.includes?(char)
            starts_with_double_separator = true
          else
            return false unless char == ':'
          end
        else
          if separators.includes?(char)
            if index == 2
              return !starts_with_double_separator && !found_share_name
            elsif found_share_name
              return true
            else
              found_share_name = true
            end
          end
        end
      end

      false
    else
      separators.includes?(@name[0]?)
    end
  end

  private def separators
    Path.separators(@kind)
  end

  def ends_with_separator?
    ends_with_separator?(@name)
  end

  private def ends_with_separator?(name)
    separators.any? { |separator| name.ends_with?(separator) }
  end

  private def starts_with_separator?(name = @name)
    separators.any? { |separator| name.starts_with?(separator) }
  end

  # Returns the string representation of this path.
  def to_s : String
    @name
  end

  # Appends the string representation of this path to *io*.
  def to_s(io : IO)
    io << to_s
  end

  # Inspects this path to *io*.
  def inspect(io : IO)
    if native?
      io << "Path["
      @name.inspect(io)
      io << ']'
    else
      io << "Path."
      io << (windows? ? "windows" : "posix")
      io << '('
      @name.inspect(io)
      io << ')'
    end
  end

  # Returns a new `URI` with `file` scheme from this path.
  #
  # A URI can only be created with an absolute path. Raises `Path::Error` if
  # this path is not absolute.
  def to_uri : URI
    raise Error.new("Cannot create a URI from relative path") unless absolute?
    URI.new(scheme: "file", path: @name)
  end

  # Returns the path of the home directory of the current user.
  def self.home : Path
    new ENV["HOME"]
  end
end
