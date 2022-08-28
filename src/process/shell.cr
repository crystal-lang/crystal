class Process
  # Converts a sequence of strings to one joined string with each argument shell-quoted.
  #
  # This is then safe to pass as part of the command when using `shell: true` or `system()`.
  #
  # NOTE: The actual return value is system-dependent, so it mustn't be relied on in other contexts.
  # See also: `quote_posix`.
  #
  # ```
  # files = ["my file.txt", "another.txt"]
  # `grep -E 'fo+' -- #{Process.quote(files)}`
  # ```
  def self.quote(args : Enumerable(String)) : String
    {% if flag?(:win32) %}
      quote_windows(args)
    {% else %}
      quote_posix(args)
    {% end %}
  end

  # Shell-quotes one item, same as `quote({arg})`.
  def self.quote(arg : String) : String
    quote({arg})
  end

  # Converts a sequence of strings to one joined string with each argument shell-quoted.
  #
  # This is then safe to pass to a POSIX shell.
  #
  # ```
  # files = ["my file.txt", "another.txt"]
  # Process.quote_posix(files) # => "'my file.txt' another.txt"
  # ```
  def self.quote_posix(args : Enumerable(String)) : String
    args.join(' ') do |arg|
      if arg.empty?
        "''"
      elsif arg.matches? %r([^a-zA-Z0-9%+,\-./:=@_]) # not all characters are safe, needs quoting
        "'" + arg.gsub("'", %('"'"')) + "'"          # %(foo'ba#r) becomes %('foo'"'"'ba#r')
      else
        arg
      end
    end
  end

  # Shell-quotes one item, same as `quote_posix({arg})`.
  def self.quote_posix(arg : String) : String
    quote_posix({arg})
  end

  # :nodoc:
  #
  # Converts a sequence of strings to one joined string with each argument shell-quoted.
  #
  # This is then safe to pass Windows API CreateProcess.
  #
  # NOTE: This is **not** safe to pass to the CMD shell.
  #
  # ```
  # files = ["my file.txt", "another.txt"]
  # Process.quote_windows(files) # => %("my file.txt" another.txt)
  # ```
  def self.quote_windows(args : Enumerable(String)) : String
    String.build { |io| quote_windows(io, args) }
  end

  private def self.quote_windows(io : IO, args)
    args.join(io, ' ') do |arg|
      need_quotes = arg.empty? || arg.includes?(' ') || arg.includes?('\t')

      io << '"' if need_quotes

      slashes = 0
      arg.each_char do |c|
        case c
        when '\\'
          slashes += 1
        when '"'
          (slashes + 1).times { io << '\\' }
          slashes = 0
        else
          slashes = 0
        end

        io << c
      end

      if need_quotes
        slashes.times { io << '\\' }
        io << '"'
      end
    end
  end

  # :nodoc:
  #
  # Shell-quotes one item, same as `quote_windows({arg})`.
  #
  # ```
  # Process.quote_windows(%q(C:\"foo" project.txt)) # => %q("C:\\\"foo\" project.txt")
  # ```
  def self.quote_windows(arg : String) : String
    quote_windows({arg})
  end

  # Splits the given *line* into individual command-line arguments in a
  # platform-specific manner, unquoting tokens if necessary.
  #
  # Equivalent to `parse_arguments_posix` on Unix-like systems. Equivalent to
  # `parse_arguments_windows` on Windows.
  def self.parse_arguments(line : String) : Array(String)
    {% if flag?(:unix) %}
      parse_arguments_posix(line)
    {% elsif flag?(:win32) %}
      parse_arguments_windows(line)
    {% else %}
      raise NotImplementedError.new("Process.parse_arguments")
    {% end %}
  end

  # Splits the given *line* into individual command-line arguments according to
  # POSIX shell rules, unquoting tokens if necessary.
  #
  # Raises `ArgumentError` if a quotation mark is unclosed.
  #
  # ```
  # Process.parse_arguments_posix(%q["foo bar" '\hello/' Fizz\ Buzz]) # => ["foo bar", "\\hello/", "Fizz Buzz"]
  # ```
  #
  # See https://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_03
  def self.parse_arguments_posix(line : String) : Array(String)
    tokens = [] of String

    reader = Char::Reader.new(line)

    while reader.has_next?
      # skip whitespace
      while reader.current_char.ascii_whitespace?
        reader.next_char
      end
      break unless reader.has_next?

      token = String.build do |str|
        while reader.has_next? && !reader.current_char.ascii_whitespace?
          quote = nil
          if reader.current_char.in?('\'', '"')
            quote = reader.current_char
            reader.next_char
          end

          until (char = reader.current_char) == quote || (!quote && (char.ascii_whitespace? || char.in?('\'', '"')))
            break unless reader.has_next?
            reader.next_char
            if char == '\\' && quote != '\''
              str << char if quote == '"'
              char = reader.current_char
              if reader.has_next?
                reader.next_char
              else
                break if quote == '"'
                char = '\\'
              end
            end
            str << char
          end

          if quote
            raise ArgumentError.new("Unmatched quote") unless reader.has_next?
            reader.next_char
          end
        end
      end

      tokens << token
    end

    tokens
  end

  # Splits the given *line* into individual command-line arguments according to
  # Microsoft's standard C runtime, unquoting tokens if necessary.
  #
  # Raises `ArgumentError` if a quotation mark is unclosed. Leading spaces in
  # *line* are ignored. Otherwise, this method is equivalent to
  # [`CommandLineToArgvW`](https://docs.microsoft.com/en-gb/windows/win32/api/shellapi/nf-shellapi-commandlinetoargvw)
  # for some unspecified program name.
  #
  # NOTE: This does **not** take strings that are passed to the CMD shell or
  # used in a batch script.
  #
  # ```
  # Process.parse_arguments_windows(%q[foo"bar \\\"hello\\" Fizz\Buzz]) # => ["foobar \\\"hello\\", "Fizz\\Buzz"]
  # ```
  def self.parse_arguments_windows(line : String) : Array(String)
    tokens = [] of String
    reader = Char::Reader.new(line)
    quote = false

    while true
      # skip whitespace
      while reader.current_char.in?(' ', '\t')
        reader.next_char
      end
      break unless reader.has_next?

      token = String.build do |str|
        while true
          backslash_count = 0
          while reader.current_char == '\\'
            backslash_count += 1
            reader.next_char
          end

          if reader.current_char == '"'
            (backslash_count // 2).times { str << '\\' }
            if backslash_count.odd?
              str << '"'
            else
              quote = !quote
            end
          else
            backslash_count.times { str << '\\' }
            break unless reader.has_next?
            # `current_char` is neither '\\' nor '"'
            char = reader.current_char
            break if char.in?(' ', '\t') && !quote
            str << char
          end

          reader.next_char
        end
      end

      tokens << token
    end

    raise ArgumentError.new("Unmatched quote") if quote
    tokens
  end
end
