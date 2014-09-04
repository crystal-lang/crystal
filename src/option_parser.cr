class OptionParser
  class Exception < ::Exception
  end

  class InvalidOption < Exception
    def initialize(option)
      super("Invalid option: #{option}")
    end
  end

  class MissingOption < Exception
    def initialize(option)
      super("Missing option: #{option}")
    end
  end

  record Handler, flag, block

  def self.parse(args)
    parser = OptionParser.new(args)
    yield parser
    parser.parse
    parser.check_invalid_options
    parser
  end

  def self.parse!
    parse(ARGV) { |parser| yield parser }
  end

  def initialize(@args)
    @flags = [] of String
    double_dash_index = @double_dash_index = @args.index("--")
    if double_dash_index
      @args.delete_at(double_dash_index)
    end
    @handlers = [] of Handler
  end

  def parse
    @handlers.each do |handler|
      parse_flag(handler.flag, &handler.block)
    end

    if unknown_args = @unknown_args
      double_dash_index = @double_dash_index
      if double_dash_index
        before_dash = @args[0 ... double_dash_index]
        after_dash = @args[double_dash_index .. -1]
      else
        before_dash = @args
        after_dash = [] of String
      end
      unknown_args.call(before_dash, after_dash)
    end
  end

  def banner=(@banner)
  end

  def on(flag, description, &block : String ->)
    append_flag flag.to_s, description
    @handlers << Handler.new(flag, block)
  end

  def on(short_flag, long_flag, description, &block : String ->)
    append_flag "#{short_flag}, #{long_flag}", description
    @handlers << Handler.new(short_flag, block)
    @handlers << Handler.new(long_flag, block)
  end

  def unknown_args(&@unknown_args : Array(String), Array(String) -> )
  end

  def to_s(io : IO)
    if banner = @banner
      io << banner
      io << "\n"
    end
    @flags.join "\n", io
  end

  private def append_flag(flag, description)
    @flags << String.build do |str|
      str << "    "
      str << flag
      (33 - flag.length).times do
        str << " "
      end
      str << description
    end
  end

  private def parse_flag(flag)
    case flag
    when /--(\S+)\s+\[\S+\]/
      value = double_flag_value("--#{MatchData.last[1]}")
      yield value if value
    when /--(\S+)(\s+|\=)(\S+)?/
      value = double_flag_value("--#{MatchData.last[1]}", true)
      yield value if value
    when /--\S+/
      flag_present?(flag) && yield ""
    when /-(.)\s*\[\S+\]/
      value = single_flag_value(flag[0 .. 1])
      yield value if value
    when /-(.)\s+\S+/, /-(.)\s+/, /-(.)\S+/
      value = single_flag_value(flag[0 .. 1], true)
      yield value if value
    else
      flag_present?(flag) && yield ""
    end
  end

  private def flag_present?(flag)
    index = args_index(flag)
    if index
      delete_arg_at_index(index)
      return true
    end

    false
  end

  private def double_flag_value(flag, raise_if_missing = false)
    each_arg_with_index do |arg, index|
      if arg.starts_with?(flag)
        if arg.length == flag.length
          delete_arg_at_index(index)
          if index < args_length
            return delete_arg_at_index(index)
          else
            if raise_if_missing
              raise MissingOption.new(flag)
            else
              return nil
            end
          end
        elsif arg[flag.length] == '='
          delete_arg_at_index(index)
          value = arg[flag.length + 1 .. -1]
          if value.empty?
            raise MissingOption.new(flag)
          else
            return value
          end
        end
      end
    end
    nil
  end

  private def single_flag_value(flag, raise_if_missing = false)
    index = args_index { |arg| arg.starts_with?(flag) }
    if index
      arg = delete_arg_at_index(index)
      if arg.length == flag.length
        if index < args_length
          delete_arg_at_index(index)
        else
          raise MissingOption.new(flag) if raise_if_missing
        end
      else
        value = arg[2 .. -1]
        raise MissingOption.new(flag) if raise_if_missing && value.empty?
        value
      end
    else
      nil
    end
  end

  private def each_arg_with_index
    if double_dash_index = @double_dash_index
      @args.each_with_index do |arg, index|
        break if index == double_dash_index
        yield arg, index
      end
    else
      @args.each_with_index do |arg, index|
        yield arg, index
      end
    end
  end

  private def args_length
    @double_dash_index || @args.length
  end

  private def args_index(flag)
    args_index { |arg| arg == flag }
  end

  private def args_index
    index = @args.index { |arg| yield arg }
    if index
      if (double_dash_index = @double_dash_index) && index >= double_dash_index
        return nil
      end
    end
    index
  end

  private def delete_arg_at_index(index)
    arg = @args.delete_at(index)
    decrement_double_dash_index
    arg
  end

  private def decrement_double_dash_index
    if double_dash_index = @double_dash_index
      @double_dash_index = double_dash_index - 1
    end
  end

  protected def check_invalid_options
    @args.each_with_index do |arg, index|
      return if (double_dash_index = @double_dash_index) && index >= double_dash_index

      if arg.starts_with?('-')
        raise InvalidOption.new(arg)
      end
    end
  end
end
