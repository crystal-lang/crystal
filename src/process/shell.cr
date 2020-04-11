class Process
  def self.shell_quote_windows(args : Enumerable(String)) : String
    String.build { |io| shell_quote_windows(args, io) }
  end

  private def self.shell_quote_windows(args, io : IO)
    args.join(' ', io) do |arg|
      quotes = arg.empty? || arg.includes?(' ') || arg.includes?('\t')

      io << '"' if quotes

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

      if quotes
        slashes.times { io << '\\' }
        io << '"'
      end
    end
  end
end
