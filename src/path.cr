require "crystal/system/path"

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
# element that is empty or equal to `"."`. Accessing a file using an empty path
# is equivalent to accessing the default directory of the process.
#
# # Examples
#
# ```
# Path["foo/bar/baz.cr"].parent    # => Path["foo/bar"]
# Path["foo/bar/baz.cr"].basename  # => "baz.cr"
# Path["./foo/../bar"].normalize   # => Path["bar"]
# Path["~/bin"].expand(home: true) # => Path["/home/crystal/bin"]
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

  # :ditto:
  def self.new(path : Path) : Path
    path.to_native
  end

  # :ditto:
  def self.new(name : String | Path, *parts : String | Path) : Path
    new(name).join(*parts)
  end

  # :ditto:
  def self.[](name : String | Path, *parts) : Path
    new(name, *parts)
  end

  # :ditto:
  def self.new(parts : Enumerable) : Path
    new("").join(parts)
  end

  # :ditto:
  def self.[](parts : Enumerable) : Path
    new(parts)
  end

  # Creates a new `Path` of POSIX kind.
  def self.posix(name : String = "") : Path
    new(name.check_no_null_byte, Kind::POSIX)
  end

  # :ditto:
  def self.posix(path : Path) : Path
    path.to_posix
  end

  # :ditto:
  def self.posix(name : String | Path, *parts : String | Path) : Path
    posix(name).join(parts)
  end

  # :ditto:
  def self.posix(parts : Enumerable) : Path
    posix("").join(parts)
  end

  # Creates a new `Path` of Windows kind.
  def self.windows(name : String = "") : Path
    new(name.check_no_null_byte, Kind::WINDOWS)
  end

  # :ditto:
  def self.windows(path : Path) : Path
    path.to_windows
  end

  # :ditto:
  def self.windows(name : String | Path, *parts : String | Path) : Path
    windows(name).join(parts)
  end

  # :ditto:
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
    return "." if @name.empty?
    slice = @name.to_slice
    sep = self.separators.map &.ord
    pos = slice.size - 1
    stage = 0

    slice.reverse_each do |byte|
      is_separator = byte.in? sep
      # The stages are ordered like this to improve performance
      # Trailing separators are possible but unlikely (stage 0)
      # There will probably only be one separator between filename and dirname (stage 2)
      # There will probably be multiple characters in the filename which need to be skipped (stage 1)
      case stage
      when 1 # Wait until separator
        stage += 1 if is_separator
      when 2 # Remove trailing separators
        break unless is_separator
      when 0 # Wait until past trailing separators
        stage += 1 unless is_separator
      end
      pos -= 1
    end

    case stage
    when 0 # Path only consists of separators
      String.new(slice[0, 1])
    when 1 # Path has no parent (ex. "hello/", "C:/", "crystal")
      return anchor.to_s if windows? && windows_drive?
      "."
    else # Path has a parent (ex. "a/a", "/home/user//", "C://Users/mmm")
      return String.new(slice[0, 1]) if pos == -1
      if windows? && pos == 1 && slice.unsafe_fetch(pos) === ':' && (anchor = self.anchor)
        return anchor.to_s
      end
      String.new(slice[0, pos + 1])
    end
  end

  # Returns the parent path of this path.
  #
  # If the path is empty, it returns `"."`. If the path is rooted
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
    return if empty?

    first_char = @name.char_at(0)
    unless separators.includes?(first_char) || (first_char == '.' && separators.includes?(@name.byte_at?(1).try &.unsafe_chr)) || (windows? && (windows_drive? || unc_share?))
      yield new_instance(".")
    end

    pos_memo = nil
    each_part_separator_index do |start_pos, length|
      # Delay yielding for each part to avoid yielding for the last part, which
      # means the entire path.
      if pos_memo
        yield new_instance(@name.byte_slice(0, pos_memo))
      end

      pos_memo = start_pos + length
    end
  end

  # Returns the last component of this path.
  #
  # If *suffix* is given, it is stripped from the end.
  #
  # In case the last component is the empty string (i.e. the path has a trailing
  # separator), the second to last component is returned.
  # For a path that only consists of an anchor, or an empty path, the base name
  # is equivalent to the full path.
  #
  # ```
  # Path["/foo/bar/file.cr"].basename # => "file.cr"
  # Path["/foo/bar/"].basename        # => "bar"
  # Path["/foo/bar/."].basename       # => "."
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
    if suffix && suffix.bytesize <= current && suffix == @name.byte_slice(current - suffix.bytesize + 1, suffix.bytesize)
      current -= suffix.bytesize
    end

    # one character left?
    return @name.byte_slice(0, 1) if current == 0

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
  # Path["foo.cr"].extension     # => ".cr"
  # Path["foo"].extension        # => ""
  # Path["foo.tar.gz"].extension # => ".gz"
  # ```
  def extension : String
    return "" if @name.bytesize < 3
    bytes = @name.to_slice
    separators = self.separators.map &.ord

    # Ignore trailing separators
    offset = bytes.size - 1
    while bytes.unsafe_fetch(offset).in? separators
      return "" if offset == 0
      offset -= 1
    end

    # Get the first occurrence of a separator or a '.' past the trailing separators
    dot_index = bytes.rindex(offset: offset) { |byte| byte === '.' || byte.in? separators }

    # Return "" if '.' is the first character (ex. ".dotfile"),
    # or if the '.' character follows after a separator (ex. "pathto/.dotfile")
    # or if the character at the returned index is a separator (ex. "no/extension")
    # or if the filename ends with a '.'
    return "" unless dot_index
    return "" if dot_index == 0
    return "" if dot_index == offset
    return "" if bytes.unsafe_fetch(dot_index - 1).in?(separators)
    return "" if bytes.unsafe_fetch(dot_index).in?(separators)

    String.new(bytes[dot_index, offset - dot_index + 1])
  end

  # Returns the last component of this path without the extension.
  #
  # This is equivalent to `self.basename(self.extension)`.
  #
  # ```
  # Path["file.cr"].stem     # => "file"
  # Path["file.tar.gz"].stem # => "file.tar"
  # Path["foo/file.cr"].stem # => "file"
  # ```
  def stem : String
    basename(extension)
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
    return new_instance "." if empty?

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
  #
  # ```
  # Path.new("foo/bar/").each_part # yields: "foo", "bar"
  # ```
  #
  # See `#parts` for more examples.
  def each_part(& : String ->)
    each_part_separator_index do |start_pos, length|
      yield @name.byte_slice(start_pos, length)
    end
  end

  # Returns the components of this path as an `Array(String)`.
  #
  # ```
  # Path.new("foo/bar/").parts                   # => ["foo", "bar"]
  # Path.new("/Users/foo/bar.cr").parts          # => ["/", "Users", "foo", "bar.cr"]
  # Path.windows("C:\\Users\\foo\\bar.cr").parts # => ["C:\\", "Users", "foo", "bar.cr"]
  # Path.posix("C:\\Users\\foo\\bar.cr").parts   # => ["C:\\Users\\foo\\bar.cr"]
  # ```
  def parts : Array(String)
    parts = [] of String
    each_part do |part|
      parts << part
    end
    parts
  end

  # Returns an iterator over all components of this path.
  #
  # ```
  # parts = Path.new("foo/bar/").each_part
  # parts.next # => "foo"
  # parts.next # => "bar"
  # parts.next # => Iterator::Stop::INSTANCE
  # ```
  #
  # See `#parts` for more examples.
  def each_part : Iterator(String)
    PartIterator.new(self)
  end

  private def each_part_separator_index(&)
    reader = Char::Reader.new(@name)
    start_pos = reader.pos

    if anchor = self.anchor
      reader.pos = anchor.@name.bytesize
      # Path is absolute, consume leading separators
      while separators.includes?(reader.current_char)
        break unless reader.has_next?
        reader.next_char
      end

      start_pos = reader.pos
      yield 0, start_pos
    end

    last_was_separator = false
    separators = self.separators

    while next_part = Path.next_part_separator_index(reader, last_was_separator, separators)
      reader, last_was_separator, start_pos = next_part

      break if reader.pos == start_pos
      yield start_pos, reader.pos - start_pos
    end
  end

  # :nodoc:
  def self.next_part_separator_index(reader : Char::Reader, last_was_separator, separators)
    start_pos = reader.pos

    reader.each do |char|
      if separators.includes?(char)
        if last_was_separator
          next
        end

        return reader, true, start_pos
      elsif last_was_separator
        start_pos = reader.pos
        last_was_separator = false
      end
    end

    unless last_was_separator
      {reader, false, start_pos}
    end
  end

  # :nodoc:
  class PartIterator
    include Iterator(String)

    def initialize(@path : Path)
      @reader = Char::Reader.new(@path.@name)
      @last_was_separator = false
      @anchor_processed = false
    end

    def next
      start_pos = next_pos

      return stop unless start_pos
      return stop if start_pos == @reader.pos

      @path.@name.byte_slice(start_pos, @reader.pos - start_pos)
    end

    private def next_pos
      unless @anchor_processed
        @anchor_processed = true
        if anchor_pos = process_anchor
          return anchor_pos
        end
      end

      next_part = Path.next_part_separator_index(@reader, @last_was_separator, @path.separators)
      return unless next_part

      @reader, @last_was_separator, start_pos = next_part

      start_pos
    end

    private def process_anchor
      anchor = @path.anchor
      return unless anchor

      reader = @reader
      reader.pos = anchor.@name.bytesize
      # Path is absolute, consume leading separators
      while @path.separators.includes?(reader.current_char)
        return unless reader.has_next?
        reader.next_char
      end

      @reader = reader
      0
    end
  end

  private def windows_drive?
    @name.byte_at?(1) === ':' && @name.char_at(0).ascii_letter?
  end

  # Converts this path to a native path.
  #
  # * `#to_kind` performs a configurable conversion.
  def to_native : Path
    to_kind(Kind.native)
  end

  # Converts this path to a Windows path.
  #
  # This creates a new instance with the same string representation but with
  # `Kind::WINDOWS`. If `#windows?` is true, this is a no-op.
  #
  # ```
  # Path.posix("foo/bar").to_windows   # => Path.windows("foo/bar")
  # Path.windows("foo/bar").to_windows # => Path.windows("foo/bar")
  # ```
  #
  # When *mappings* is `true` (default), forbidden characters in Windows paths are
  # substituted by replacement characters when converting from a POSIX path.
  # Replacements are calculated by adding `0xF000` to their codepoint.
  # For example, the backslash character `U+005C` becomes `U+F05C`.
  #
  # ```
  # Path.posix("foo\\bar").to_windows(mappings: true)  # => Path.windows("foo\uF05Cbar")
  # Path.posix("foo\\bar").to_windows(mappings: false) # => Path.windows("foo\\bar")
  # ```
  #
  # * `#to_posix` performs the inverse conversion.
  # * `#to_kind` performs a configurable conversion.
  def to_windows(*, mappings : Bool = true) : Path
    name = @name
    if posix? && mappings
      name = name.tr(WINDOWS_ESCAPE_CHARACTERS, WINDOWS_ESCAPED_CHARACTERS)
    end
    new_instance(name, Kind::WINDOWS)
  end

  # :nodoc:
  WINDOWS_ESCAPE_CHARACTERS = %("*:<>?\\| )
  # :nodoc:
  WINDOWS_ESCAPED_CHARACTERS = "\uF022\uF02A\uF03A\uF03C\uF03E\uF03F\uF05C\uF07C\uF020"

  # Converts this path to a POSIX path.
  #
  # It returns a new instance with `Kind::POSIX` and all occurrences of Windows'
  # backslash file separators (`\\`) replaced by forward slash (`/`).
  # If `#posix?` is true, this is a no-op.
  #
  # ```
  # Path.windows("foo/bar\\baz").to_posix # => Path.posix("foo/bar/baz")
  # Path.posix("foo/bar\\baz").to_posix   # => Path.posix("foo/bar\\baz")
  # ```
  #
  # When *mappings* is `true` (default), replacements  for forbidden characters in Windows
  # paths are substituted by the original characters when converting to a POSIX path.
  # Originals are calculated by subtracting `0xF000` from the replacement codepoint.
  # For example, the `U+F05C` becomes `U+005C`, the backslash character.
  #
  # ```
  # Path.windows("foo\uF05Cbar").to_posix(mappings: true)  # => Path.posix("foo\\bar")
  # Path.windows("foo\uF05Cbar").to_posix(mappings: false) # => Path.posix("foo\uF05Cbar")
  # ```
  #
  # * `#to_windows` performs the inverse conversion.
  # * `#to_kind` performs a configurable conversion.
  def to_posix(*, mappings : Bool = true) : Path
    name = @name
    if windows?
      name = name.gsub('\\', '/')
      if mappings
        name = name.tr(WINDOWS_ESCAPED_CHARACTERS, WINDOWS_ESCAPE_CHARACTERS)
      end
    end
    new_instance(name, Kind::POSIX)
  end

  # Converts this path to the given *kind*.
  #
  # See `#to_windows` and `#to_posix` for details.
  #
  # * `#to_native` converts to the native path semantics.
  def to_kind(kind, *, mappings : Bool = true) : Path
    if kind.posix?
      to_posix(mappings: mappings)
    else
      to_windows(mappings: mappings)
    end
  end

  # Converts this path to an absolute path. Relative paths are
  # referenced from the current working directory of the process (`Dir.current`)
  # unless *base* is given, in which case it will be used as the reference path.
  #
  # ```
  # Path["foo"].expand                 # => Path["/current/path/foo"]
  # Path["~/foo"].expand(home: "/bar") # => Path["/bar/foo"]
  # Path["baz"].expand("/foo/bar")     # => Path["/foo/bar/baz"]
  # ```
  #
  # *home* specifies the home directory which `~` will expand to.
  # "~" is expanded to the value passed to *home*.
  # If it is `false` (default), home is not expanded.
  # If `true`, it is expanded to the user's home directory (`Path.home`).
  #
  # If *expand_base* is `true`, *base* itself will be expanded in `Dir.current`
  # if it is not an absolute path. This guarantees the method returns an absolute
  # path (assuming that `Dir.current` is absolute).
  def expand(base : Path | String = Dir.current, *, home : Path | String | Bool = false, expand_base = true) : Path
    base = Path.new(base) unless base.is_a?(Path)
    base = base.to_kind(@kind)
    if base == self
      # expanding base, avoid recursion
      return new_instance(@name).normalize(remove_final_separator: false)
    end

    name = @name

    if home
      if name == "~"
        name = resolve_home(home).to_s
      elsif name.starts_with?("~/") || (windows? && name.starts_with?("~\\"))
        name = resolve_home(home).join(name.byte_slice(2, name.bytesize - 2)).to_s
      end
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

  private def resolve_home(home)
    case home
    when String then home = Path[home]
    when Bool   then home = Path.home
    when Path # no transformation needed
    end

    home.to_kind(@kind).normalize
  end

  # Appends the given *part* to this path and returns the joined path.
  #
  # ```
  # Path["foo"].join("bar")     # => Path["foo/bar"]
  # Path["foo/"].join("/bar")   # => Path["foo/bar"]
  # Path["/foo/"].join("/bar/") # => Path["/foo/bar/"]
  # ```
  #
  # Joining an empty string (`""`) appends a trailing path separator.
  # In case the path already ends with a trailing separator, no additional
  # separator is added.
  #
  # ```
  # Path["a/b"].join("")   # => Path["a/b/"]
  # Path["a/b/"].join("")  # => Path["a/b/"]
  # Path["a/b/"].join("c") # => Path["a/b/c"]
  # ```
  def join(part) : Path
    # If we are joining a single part we can use `String.new` instead of
    # `String.build` which avoids an extra allocation.
    # Given that `File.join(arg1, arg2)` is the most common usage
    # it's good if we can optimize this case.

    if part.is_a?(Path)
      part = part.to_kind(@kind).to_s
    else
      part = part.to_s
      part.check_no_null_byte
    end

    if @name.empty?
      if part.empty?
        # We could use `separators[0].to_s` but then we'd have to
        # convert Char to String which involves a memory allocation
        return new_instance(windows? ? "\\" : "/")
      else
        return new_instance(part)
      end
    end

    bytesize = @name.bytesize + part.bytesize # bytesize of the resulting string
    add_separator = false                     # do we need to add a separate between the parts?
    part_ptr = part.to_unsafe                 # where do we start copying from `part`?
    part_bytesize = part.bytesize             # how much do we copy from `part`?

    case {ends_with_separator?, starts_with_separator?(part)}
    when {true, true}
      # There are separators on both sides so we'll just lchop from the right part
      bytesize -= 1
      part_ptr += 1
      part_bytesize -= 1
    when {false, false}
      # No separators on any side so we need to add one
      bytesize += 1
      add_separator = true
    else
      # There's at least on separator in the middle, so nothing to do
    end

    new_name = String.new(bytesize) do |buffer|
      # Copy name
      buffer.copy_from(@name.to_unsafe, @name.bytesize)
      buffer += @name.bytesize

      # Add separator if needed
      if add_separator
        buffer.value = separators[0].ord.to_u8
        buffer += 1
      end

      # Copy the part
      buffer.copy_from(part_ptr, part_bytesize)

      {bytesize, @name.single_byte_optimizable? && part.single_byte_optimizable? ? bytesize : 0}
    end

    new_instance new_name
  end

  # Appends the given *parts* to this path and returns the joined path.
  #
  # ```
  # Path["foo"].join("bar", "baz")       # => Path["foo/bar/baz"]
  # Path["foo/"].join("/bar/", "/baz")   # => Path["foo/bar/baz"]
  # Path["/foo/"].join("/bar/", "/baz/") # => Path["/foo/bar/baz/"]
  # ```
  #
  # See `join(part)` for details.
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
  #
  # See `join(part)` for details.
  def join(parts : Enumerable) : Path
    parts.reduce(self) { |path, part| path.join(part) }
  end

  # Appends the given *part* to this path and returns the joined path.
  #
  # ```
  # Path["foo"] / "bar" / "baz"     # => Path["foo/bar/baz"]
  # Path["foo/"] / Path["/bar/baz"] # => Path["foo/bar/baz"]
  # ```
  #
  # See `join(part)` for details.
  def /(part : Path | String) : Path
    join(part)
  end

  # Resolves path *name* in this path's parent directory.
  #
  # Raises `Path::Error` if `#parent` is `nil`.
  def sibling(name : Path | String) : Path
    if parent = self.parent
      parent.join(name)
    else
      raise Error.new("Can't resolve sibling for a path without parent directory")
    end
  end

  private def empty?
    @name.empty? || @name == "."
  end

  # Returns a relative path that is lexically equivalent to `self` when joined
  # to *base* with an intervening separator.
  #
  # The returned path is in normalized form.
  #
  # That means with normalized paths `base.join(target.relative_to(base))` is
  # equivalent to `target`.
  #
  # Returns `nil` if `self` cannot be expressed as relative to *base* or if
  # knowing the current working directory would be necessary to resolve it. The
  # latter can be avoided by expanding the paths first.
  def relative_to?(base : Path) : Path?
    base_anchor = base.anchor
    target_anchor = self.anchor

    # if paths have a different anchors, there can't be a relative path between
    # them.
    if base_anchor != target_anchor
      return nil
    end

    # work on normalized paths otherwise we would need to backtrack on `..` parts
    base = base.normalize
    target = self.normalize

    # check for trivial case of equal paths
    if base == target
      return new_instance(".")
    end

    base_iterator = base.each_part
    target_iterator = target.each_part

    if target_anchor
      # process anchors, we have already established they're equal
      base_iterator.next
      target_iterator.next
    end

    # consume both paths simultaneously as long as they have identical components
    base_part = base_iterator.next
    target_part = target_iterator.next
    while base_part.is_a?(String) && target_part.is_a?(String)
      if base_part.compare(target_part, case_insensitive: windows?) != 0
        break
      end

      base_part = base_iterator.next
      target_part = target_iterator.next
    end

    path = new_instance("")

    # base_path is not consumed, so we go up before descending into target_path
    if base_part.is_a?(String)
      # Can't relativize upwards from current working directory without knowing
      # its path
      if base_part == ".."
        return nil
      end

      path /= ".." unless base_part == "."
      base_iterator.each do
        path /= ".."
      end
    end

    # target_path is not consumed, so we append what's left to the relative path
    if target_part.is_a?(String)
      path /= target_part
      target_iterator.each do |part|
        path /= part
      end
    end

    path
  end

  # :ditto:
  def relative_to?(base : String) : Path?
    relative_to?(new_instance(base))
  end

  # Same as `#relative_to` but returns `self` if `self` can't be expressed as
  # relative path to *base*.
  def relative_to(base : Path | String) : Path
    relative_to?(base) || self
  end

  # Compares this path to *other*.
  #
  # The comparison is performed strictly lexically: `foo` and `./foo` are *not*
  # treated as equal. Nor are paths of different `kind`.
  # To compare paths semantically, they need to be normalized and converted to
  # the same kind.
  #
  # ```
  # Path["foo"] <=> Path["foo"]               # => 0
  # Path["foo"] <=> Path["./foo"]             # => 1
  # Path["foo"] <=> Path["foo/"]              # => -1
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
    ord = @name.compare(other.@name, case_insensitive: windows? || other.windows?)
    return ord if ord != 0

    @kind <=> other.@kind
  end

  # Returns `true` if this path is considered equivalent to *other*.
  #
  # The comparison is performed strictly lexically: `foo` and `./foo` are *not*
  # treated as equal. Nor are paths of different `kind`.
  # To compare paths semantically, they need to be normalized and converted to
  # the same kind.
  #
  # ```
  # Path["foo"] == Path["foo"]               # => true
  # Path["foo"] == Path["./foo"]             # => false
  # Path["foo"] == Path["foo/"]              # => false
  # Path.posix("foo") == Path.windows("foo") # => false
  # ```
  #
  # Comparison is case-sensitive for POSIX paths and case-insensitive for
  # Windows paths.
  #
  # ```
  # Path.posix("foo") == Path.posix("FOO")     # => false
  # Path.windows("foo") == Path.windows("FOO") # => true
  # ```
  def ==(other : self)
    return false if @kind != other.@kind

    @name.compare(other.@name, case_insensitive: windows? || other.windows?) == 0
  end

  def hash(hasher)
    name = @name
    if windows?
      name = name.downcase
    end
    hasher = name.hash(hasher)
    @kind.hash(hasher)
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
      if windows_drive?
        drive = @name.byte_slice(0, 2)
        if separators.includes?(@name.byte_at?(2).try(&.chr))
          return drive, @name.byte_slice(2, 1)
        else
          return drive, nil
        end
      elsif unc_share = unc_share?
        share_end, root_end = unc_share
        if share_end == root_end
          root = nil
        else
          root = @name.byte_slice(share_end, root_end - share_end)
        end

        return @name.byte_slice(0, share_end), root
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

  private def unc_share?
    # Test for UNC share
    # path: //share/share
    # part: 1122222 33333

    # Grammar definition: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/62e862f4-2a51-452e-8eeb-dc4ff5ee33cc?redirectedfrom=MSDN

    return unless @name.size >= 5

    reader = Char::Reader.new(@name)

    # 1. Consume two leading separators
    char = reader.current_char
    return unless separators.includes?(char) && char == reader.next_char
    reader.next_char

    # 2. Consume first path component
    # The first component is either an IPv4 address or a hostname.
    # IPv6 addresses are converted into hostnames by replacing all `:`s with
    # `-`s, and then appending `.ipv6-literal.net`, so raw IPv6 addresses cannot
    # appear here.
    # Hostname follows the grammar of `reg-name` in [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986).
    return if separators.includes?(reader.current_char)
    while true
      char = reader.current_char
      break if separators.includes?(char)
      if char == '%'
        # percent encoded character
        return unless reader.has_next?
        reader.next_char
        return unless reader.current_char.ascii_number?
        return unless reader.has_next?
        reader.next_char
        return unless reader.current_char.ascii_number?
      else
        # unreserved / sub-delims
        return unless char.ascii_alphanumeric? || char.in?('_', '.', '-', '~', '!', '$', ';', '=') || char.in?('&'..',')
      end
      return unless reader.has_next?
      reader.next_char
    end

    # Consume separator
    char = reader.next_char
    return if separators.includes?(char)

    return unless reader.has_next?
    reader.next_char

    # 3. Consume second path component
    # `share-name` in UNC grammar
    while true
      char = reader.current_char
      break if separators.includes?(char) || !reader.has_next?
      return unless char.ascii_alphanumeric? || char.in?(' ', '!', '-', '.', '@', '^', '_', '`', '{', '}', '~') || char.in?('#'..')') || char.ord.in?(0x80..0xFF)
      reader.next_char
    end

    # Consume optional trailing separators
    share_end = reader.pos
    while reader.has_next?
      char = reader.next_char
      break unless separators.includes?(char)
    end

    return share_end, reader.pos
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

  # :nodoc:
  def separators
    Path.separators(@kind)
  end

  def ends_with_separator? : Bool
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
    new(Crystal::System::Path.home)
  end
end
