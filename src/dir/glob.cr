class Dir
  def self.[](*patterns) : Array(String)
    glob(patterns)
  end

  def self.[](patterns : Enumerable(String)) : Array(String)
    glob(patterns)
  end

  def self.glob(*patterns) : Array(String)
    glob(patterns)
  end

  def self.glob(*patterns)
    glob(patterns) do |pattern|
      yield pattern
    end
  end

  def self.glob(patterns : Enumerable(String)) : Array(String)
    paths = [] of String
    glob(patterns) do |path|
      paths << path
    end
    paths
  end

  def self.glob(patterns : Enumerable(String))
    special = {'*', '?', '{', '}'}
    cwd = self.current
    root = File::SEPARATOR_STRING
    patterns.each do |ptrn|
      next if ptrn.empty?

      starts_with_path_separator = ptrn.starts_with?(File::SEPARATOR)

      # If the pattern ends with a file separator we only want leaf
      # directories: regex is the same as the one without that last char
      wants_dir = false
      if ptrn.ends_with?(File::SEPARATOR)
        ptrn = ptrn.rchop
        wants_dir = true
      end

      recursion_depth = ptrn.count(File::SEPARATOR)

      if starts_with_path_separator
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
      last_is_file_separator = false
      count = 0
      nested_path = String.build do |str|
        ptrn.each_char_with_index do |c, i|
          if c == '\\'
            escaped = true
            last_is_file_separator = false
            next
          elsif c == File::SEPARATOR
            unless last_is_file_separator
              depth += 1
              str << c
              count += 1
            end
            lastidx = count
            last_is_file_separator = true
          elsif !escaped && special.includes? c
            break
          else
            last_is_file_separator = false
            str << c
            count += 1
          end
          escaped = false
        end
      end
      nested_path = nested_path[0...lastidx]

      recursion_depth -= depth if recursion_depth != Int32::MAX
      dir = File.join(dir, nested_path)
      if !nested_path.empty? && nested_path[0] == File::SEPARATOR
        nested_path = nested_path[1..-1]
      end

      regex = glob2regex(ptrn)

      scandir(dir, nested_path, regex, 0, recursion_depth, wants_dir) do |path|
        if starts_with_path_separator
          yield File::SEPARATOR + path
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

    last_is_file_separator = false

    regex_pattern = String.build do |str|
      str << "\\A"
      idx = 0
      nest = 0

      idx = 1 if pattern[0] == File::SEPARATOR
      size = pattern.size

      while idx < size
        char = pattern[idx]

        if last_is_file_separator && char == File::SEPARATOR
          idx += 1
          next
        end

        last_is_file_separator = char == File::SEPARATOR

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
            str << "[^\\" << File::SEPARATOR << "]*"
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
      str << "\\z"
    end

    Regex.new(regex_pattern)
  end

  private def self.scandir(dir_path, rel_path, regex, level, max_level, wants_dir)
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
          if f != "." && f != ".." && (level <= max_level || max_level == Int32::MAX)
            if relpath =~ regex
              if wants_dir
                yield relpath + File::SEPARATOR
              else
                yield relpath
              end
            end

            if level < max_level
              dir_path_stack.push fullpath
              rel_path_stack.push relpath
              level_stack.push level + 1
              dir_path = dir_path_stack.last
              rel_path = rel_path_stack.last
              level = level_stack.last
              recurse = true
              next
            end
          end
        else
          if !wants_dir && (level <= max_level || max_level == Int32::MAX)
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
end
