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
      process_handler handler
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

  setter banner

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

  private def process_handler(handler)
    flag = handler.flag
    block = handler.block
    case flag
    when /--(\S+)\s+\[\S+\]/
      process_double_flag("--#{$1}", block)
    when /--(\S+)(\s+|\=)(\S+)?/
      process_double_flag("--#{$1}", block, true)
    when /--\S+/
      process_flag_presence(flag, block)
    when /-(.)\s*\[\S+\]/
      process_single_flag(flag[0 .. 1], block)
    when /-(.)\s+\S+/, /-(.)\s+/, /-(.)\S+/
      process_single_flag(flag[0 .. 1], block, true)
    else
      process_flag_presence(flag, block)
    end
  end

  private def process_flag_presence(flag, block)
    while index = args_index(flag)
      delete_arg_at_index(index)
      block.call ""
    end
  end

  private def process_double_flag(flag, block, raise_if_missing = false)
    while index = args_index { |arg| arg.starts_with?(flag) }
      arg = @args[index]
      if arg.length == flag.length
        delete_arg_at_index(index)
        if index < args_length
          block.call delete_arg_at_index(index)
        else
          if raise_if_missing
            raise MissingOption.new(flag)
          end
        end
      elsif arg[flag.length] == '='
        delete_arg_at_index(index)
        value = arg[flag.length + 1 .. -1]
        if value.empty?
          raise MissingOption.new(flag)
        else
          block.call value
        end
      end
    end
  end

  private def process_single_flag(flag, block, raise_if_missing = false)
    while index = args_index { |arg| arg.starts_with?(flag) }
      arg = delete_arg_at_index(index)
      if arg.length == flag.length
        if index < args_length
          block.call delete_arg_at_index(index)
        else
          raise MissingOption.new(flag) if raise_if_missing
        end
      else
        value = arg[2 .. -1]
        raise MissingOption.new(flag) if raise_if_missing && value.empty?
        block.call value
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
