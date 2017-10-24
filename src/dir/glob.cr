class Dir
  # Returns an array of all files that match against any of *patterns*.
  #
  # The pattern syntax is similar to shell filename globbing. It may contain the following metacharacters:
  #
  # * `*` matches an unlimited number of arbitrary characters.
  #   * `"*"` matches all regular files.
  #   * `"c*"` matches all files beginning with `c`.
  #   * `"*c"` matches all files ending with `c`.
  #   * `"*c*"` matches all files that have `c` in them (including at the beginning or end).
  # * `**` matches directories recursively or files expansively.
  # * `?` matches any one character.
  # * `{a,b}` matches subpattern `a` or `b`.
  #
  # NOTE: Path separator in patterns is `/` even on Windows. The returned file names use system-specific path separators.
  def self.[](*patterns) : Array(String)
    glob(patterns)
  end

  # ditto
  def self.[](patterns : Enumerable(String)) : Array(String)
    glob(patterns)
  end

  # Returns an array of all files that match against any of *patterns*.
  #
  # The pattern syntax is similar to shell filename globbing. It may contain the following metacharacters:
  #
  # * `*` matches an unlimited number of arbitrary characters.
  #   * `"*"` matches all regular files.
  #   * `"c*"` matches all files beginning with `c`.
  #   * `"*c"` matches all files ending with `c`.
  #   * `"*c*"` matches all files that have `c` in them (including at the beginning or end).
  # * `**` matches directories recursively or files expansively.
  # * `?` matches any one character.
  # * `{a,b}` matches subpattern `a` or `b`.
  #
  # **options:**
  # * *allow_dots*: Match hidden files if `true` (default: `false`).
  #
  # NOTE: Path separator in patterns is `/` even on Windows. The returned file names use system-specific path separators.
  def self.glob(*patterns, **options) : Array(String)
    glob(patterns, **options)
  end

  # ditto
  def self.glob(patterns : Enumerable(String), **options) : Array(String)
    paths = [] of String
    glob(patterns, **options) do |path|
      paths << path
    end
    paths
  end

  # Yields all files that match against any of *patterns*.
  #
  # The pattern syntax is similar to shell filename globbing. It may contain the following metacharacters:
  #
  # * `*` matches an unlimited number of arbitrary characters.
  #   * `"*"` matches all regular files.
  #   * `"c*"` matches all files beginning with `c`.
  #   * `"*c"` matches all files ending with `c`.
  #   * `"*c*"` matches all files that have `c` in them (including at the beginning or end).
  # * `**` matches directories recursively or files expansively.
  # * `?` matches any one character.
  # * `{a,b}` matches subpattern `a` or `b`.
  #
  # **options:**
  # * *allow_dots*: Match hidden files if `true` (default: `false`).
  #
  # NOTE: Path separator in patterns is `/` even on Windows. The returned file names use system-specific path separators.
  def self.glob(*patterns, **options, &block : String -> _)
    glob(patterns, **options) do |path|
      yield path
    end
  end

  # ditto
  def self.glob(patterns : Enumerable(String), **options, &block : String -> _)
    Globber.new(**options).glob(patterns) do |path|
      yield path
    end
  end

  # :nodoc:
  struct Globber
    record DirectoriesOnly
    record ConstantEntry, path : String
    record EntryMatch, pattern : String do
      def matches?(string)
        File.fnmatch(pattern, string)
      end
    end
    record StartRecursiveDirectories
    record RecursiveDirectories
    record ConstantDirectory, path : String
    record RootDirectory
    record DirectoryMatch, pattern : String do
      def matches?(string)
        File.fnmatch(pattern, string)
      end
    end
    alias PatternType = DirectoriesOnly | ConstantEntry | EntryMatch | StartRecursiveDirectories | RecursiveDirectories | ConstantDirectory | RootDirectory | DirectoryMatch

    property? allow_dots

    def initialize(@allow_dots = false)
    end

    def glob(patterns : Enumerable(String), &block : String -> _)
      patterns.each do |pattern|
        sequences = compile(pattern)

        sequences.each do |sequence|
          run(sequence) do |match|
            yield match
          end
        end
      end
    end

    private def compile(pattern, patterns = [] of Array(PatternType))
      reader = Char::Reader.new(pattern)

      lbrace = nil
      rbrace = nil
      alt_start = nil

      alternatives = [] of String

      nest = 0
      while char = reader.current_char
        case char
        when Char::ZERO
          break
        when '{'
          lbrace = reader.pos if nest == 0
          nest += 1
        when '}'
          nest -= 1

          if nest == 0
            rbrace = reader.pos
            start = (alt_start || lbrace).not_nil! + 1
            alternatives << pattern.byte_slice(start, reader.pos - start)
            break
          end
        when ','
          if nest == 1
            start = (alt_start || lbrace).not_nil! + 1
            alternatives << pattern.byte_slice(start, reader.pos - start)
            alt_start = reader.pos
          end
        end

        reader.next_char
      end

      if lbrace && rbrace
        front = pattern.byte_slice(0, lbrace)
        back = pattern.byte_slice(rbrace + 1)

        alternatives.each do |alt|
          brace_pattern = [front, alt, back].join

          compile brace_pattern, patterns
        end
      else
        patterns << single_compile pattern
      end

      patterns
    end

    private def single_compile(glob)
      list = [] of PatternType
      return list if glob.empty?

      parts = glob.split('/', remove_empty: true)

      if glob.ends_with?('/')
        list << DirectoriesOnly.new
      else
        file = parts.pop
        if /^[a-zA-Z0-9._]+$/.match(file)
          list << ConstantEntry.new file
        elsif !file.empty?
          list << EntryMatch.new file
        end
      end

      while !parts.empty?
        dir = parts.pop

        case dir
        when "**"
          if parts.empty?
            list << StartRecursiveDirectories.new
          else
            list << RecursiveDirectories.new
          end
        when /^[^\*\?\]]+$/
          case last = list[-1]
          when ConstantDirectory
            list[-1] = ConstantDirectory.new File.join(dir, last.path)
          when ConstantEntry
            list[-1] = ConstantEntry.new File.join(dir, last.path)
          else
            list << ConstantDirectory.new dir
          end
        when .empty?
        else
          list << DirectoryMatch.new dir
        end
      end

      if glob.starts_with?('/')
        list << RootDirectory.new
      end

      list
    end

    private def run(sequence, &block : String -> _)
      return if sequence.empty?

      path_stack = [] of Tuple(Int32, String?)
      path_stack << {sequence.size - 1, nil}

      while !path_stack.empty?
        pos, path = path_stack.pop
        cmd = sequence[pos]

        next_pos = pos - 1
        case cmd
        when RootDirectory
          raise "unreachable" if path
          path_stack << {next_pos, root}
        when DirectoriesOnly
          raise "unreachable" unless path
          fullpath = path == File::SEPARATOR_STRING ? path : path + File::SEPARATOR
          yield fullpath if dir?(fullpath)
        when EntryMatch
          return if sequence[pos + 1]?.is_a?(RecursiveDirectories | StartRecursiveDirectories)
          each_child(path) do |entry|
            yield join(path, entry) if cmd.matches?(entry)
          end
        when DirectoryMatch
          next_cmd = sequence[next_pos]?

          each_child(path) do |entry|
            if cmd.matches?(entry)
              fullpath = join(path, entry)
              if dir?(fullpath)
                path_stack << {next_pos, fullpath}
              end
            end
          end
        when ConstantEntry
          return if sequence[pos + 1]?.is_a?(RecursiveDirectories | StartRecursiveDirectories)
          full = join(path, cmd.path)
          yield full if File.exists?(full)
        when ConstantDirectory
          path_stack << {next_pos, join(path, cmd.path)}
          # Don't check if full exists. It just costs us time
          # and the downstream node will be able to check properly.
        when RecursiveDirectories, StartRecursiveDirectories
          path_stack << {next_pos, path}
          next_cmd = sequence[next_pos]?

          dir_path = path || ""
          dir_stack = [] of Dir
          dir_path_stack = [dir_path]
          begin
            dir = Dir.new(path || ".")
            dir_stack << dir
          rescue Errno
            return
          end
          recurse = false

          until dir_path_stack.empty?
            if recurse
              begin
                dir = Dir.new(dir_path)
              rescue Errno
                dir_path_stack.pop
                break if dir_path_stack.empty?
                dir_path = dir_path_stack.last
                next
              ensure
                recurse = false
              end
              dir_stack.push dir
            end

            if entry = dir.try(&.read)
              next if {".", ".."}.includes?(entry)
              next if entry[0] == '.' && !allow_dots?

              if dir_path.bytesize == 0
                fullpath = entry
              else
                fullpath = File.join(dir_path, entry)
              end

              case next_cmd
              when ConstantEntry
                yield fullpath if next_cmd.path == entry
              when EntryMatch
                yield fullpath if next_cmd.matches?(entry)
              end

              if dir?(fullpath)
                path_stack << {next_pos, fullpath}

                dir_path_stack.push fullpath
                dir_path = dir_path_stack.last
                recurse = true
                next
              end
            else
              dir.try(&.close)
              dir_path_stack.pop
              dir_stack.pop
              break if dir_path_stack.empty?
              dir_path = dir_path_stack.last
              dir = dir_stack.last
            end
          end
        else
          raise "unreachable"
        end
      end
    end

    private def root
      # TODO: better implementation for windows?
      {% if flag?(:windows) %}
      "C:\\"
      {% else %}
      File::SEPARATOR_STRING
      {% end %}
    end

    private def dir?(path)
      return true unless path
      stat = File.lstat(path)
      stat.directory? && !stat.symlink?
    rescue Errno
      false
    end

    private def join(path, entry)
      return entry unless path
      return "#{root}#{entry}" if path == File::SEPARATOR_STRING

      File.join(path, entry)
    end

    private def each_child(path)
      Dir.each_child(path || Dir.current) do |entry|
        yield entry
      end
    rescue exc : Errno
      raise exc unless exc.errno == Errno::ENOENT
    end
  end
end
