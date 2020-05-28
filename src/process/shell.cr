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
end
