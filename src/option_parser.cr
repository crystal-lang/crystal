# `OptionParser` is a class for command-line options processing. It supports:
#
# * Short and long modifier style options (example: `-h`, `--help`)
# * Passing arguments to the flags (example: `-f filename.txt`)
# * Automatic help message generation
#
# Run `crystal` for an example of a CLI built with `OptionParser`.
#
# Short example:
#
# ```
# require "option_parser"
#
# upcase = false
# destination = "World"
#
# OptionParser.parse! do |parser|
#   parser.banner = "Usage: salute [arguments]"
#   parser.on("-u", "--upcase", "Upcases the salute") { upcase = true }
#   parser.on("-t NAME", "--to=NAME", "Specifies the name to salute") { |name| destination = name }
#   parser.on("-h", "--help", "Show this help") { puts parser }
# end
#
# destination = destination.upcase if upcase
# puts "Hello #{destination}!"
# ```
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

  # :nodoc:
  record Handler,
    flag : String,
    block : String ->

  # Creates a new parser, with its configuration specified in the block,
  # and uses it to parse the passed *args*.
  def self.parse(args) : self
    parser = OptionParser.new
    yield parser
    parser.parse(args)
    parser
  end

  # Creates a new parser, with its configuration specified in the block,
  # and uses it to parse the arguments passed to the program.
  def self.parse! : self
    parse(ARGV) { |parser| yield parser }
  end

  protected property flags : Array(String)
  protected property handlers : Array(Handler)
  protected property unknown_args
  protected property missing_option
  protected property invalid_option

  # Creates a new parser.
  def initialize
    @flags = [] of String
    @handlers = [] of Handler
    @missing_option = ->(option : String) { raise MissingOption.new(option) }
    @invalid_option = ->(option : String) { raise InvalidOption.new(option) }
  end

  # Creates a new parser, with its configuration specified in the block.
  def self.new
    new.tap { |parser| yield parser }
  end

  # Establishes the initial message for the help printout.
  # Typically, you want to write here the name of your program,
  # and a one-line template of its invocation.
  #
  # Example:
  #
  # ```
  # parser = OptionParser.new
  # parser.banner = "Usage: crystal [command] [switches] [program file] [--] [arguments]"
  # ```
  setter banner : String?

  # Establishes a handler for a *flag*.
  #
  # Flags must start with a dash or double dash. They can also have
  # an optional argument, which will get passed to the block.
  # Each flag has a description, which will be used for the help message.
  #
  # Examples of valid flags:
  #
  # * `-a`, `-B`
  # * `--something-longer`
  # * `-f FILE`, `--file FILE`, `--file=FILE` (these will yield the passed value to the block as a string)
  def on(flag : String, description : String, &block : String ->)
    check_starts_with_dash flag, "flag"

    append_flag flag, description
    @handlers << Handler.new(flag, block)
  end

  # Establishes a handler for a pair of short and long flags.
  #
  # See the other definition of `on` for examples.
  def on(short_flag : String, long_flag : String, description : String, &block : String ->)
    check_starts_with_dash short_flag, "short_flag", allow_empty: true
    check_starts_with_dash long_flag, "long_flag"

    append_flag "#{short_flag}, #{long_flag}", description

    has_argument = /([ =].+)/
    if long_flag =~ has_argument
      argument = $1
      short_flag += argument unless short_flag =~ has_argument
    end

    @handlers << Handler.new(short_flag, block)
    @handlers << Handler.new(long_flag, block)
  end

  # Adds a separator, with an optional header message,
  # that will be used to print the help.
  #
  # This way, you can group the different options in an easier to read way.
  def separator(message = "")
    @flags << message.to_s
  end

  # Sets a handler for regular arguments that didn't match any of the setup options.
  #
  # You typically use this to get the main arguments (not modifiers)
  # that your program expects (for example, filenames)
  def unknown_args(&@unknown_args : Array(String), Array(String) ->)
  end

  # Sets a handler for when a option that expects an argument wasn't given any.
  #
  # You typically use this to display a help message.
  # The default raises `MissingOption`.
  def missing_option(&@missing_option : String ->)
  end

  # Sets a handler for option arguments that didn't match any of the setup options.
  #
  # You typically use this to display a help message.
  # The default raises `InvalidOption`.
  def invalid_option(&@invalid_option : String ->)
  end

  # Returns all the setup options, formatted in a help message.
  def to_s(io : IO)
    if banner = @banner
      io << banner
      io << "\n"
    end
    @flags.join "\n", io
  end

  private def append_flag(flag, description)
    if flag.size >= 33
      @flags << "    #{flag}\n#{" " * 37}#{description}"
    else
      @flags << "    #{flag}#{" " * (33 - flag.size)}#{description}"
    end
  end

  # Parses the passed *args*, running the handlers associated to each option.
  def parse(args)
    ParseTask.new(self, args).parse
  end

  # Parses the passed the arguments passed to the program,
  # running the handlers associated to each option.
  def parse!
    parse ARGV
  end

  private def check_starts_with_dash(arg, name, allow_empty = false)
    return if allow_empty && arg.empty?

    unless arg.starts_with?('-')
      raise ArgumentError.new("Argument '#{name}' (#{arg.inspect}) must start with a dash (-)")
    end
  end

  private struct ParseTask
    @double_dash_index : Int32?

    def initialize(@parser : OptionParser, @args : Array(String))
      double_dash_index = @double_dash_index = @args.index("--")
      if double_dash_index
        @args.delete_at(double_dash_index)
      end
    end

    def parse
      @parser.handlers.each do |handler|
        process_handler handler
      end

      if unknown_args = @parser.unknown_args
        double_dash_index = @double_dash_index
        if double_dash_index
          before_dash = @args[0...double_dash_index]
          after_dash = @args[double_dash_index..-1]
        else
          before_dash = @args
          after_dash = [] of String
        end
        unknown_args.call(before_dash, after_dash)
      end

      check_invalid_options
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
        process_single_flag(flag[0..1], block)
      when /-(.)\s+\S+/, /-(.)\s+/, /-(.)\S+/
        process_single_flag(flag[0..1], block, true)
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
      while index = args_index { |arg| arg.split("=")[0] == flag }
        arg = @args[index]
        if arg.size == flag.size
          delete_arg_at_index(index)
          if index < args_size
            block.call delete_arg_at_index(index)
          else
            if raise_if_missing
              @parser.missing_option.call(flag)
            end
          end
        elsif arg[flag.size] == '='
          delete_arg_at_index(index)
          value = arg[flag.size + 1..-1]
          if value.empty?
            @parser.missing_option.call(flag)
          else
            block.call value
          end
        end
      end
    end

    private def process_single_flag(flag, block, raise_if_missing = false)
      while index = args_index { |arg| arg.starts_with?(flag) }
        arg = delete_arg_at_index(index)
        if arg.size == flag.size
          if index < args_size
            block.call delete_arg_at_index(index)
          else
            @parser.missing_option.call(flag) if raise_if_missing
          end
        else
          value = arg[2..-1]
          @parser.missing_option.call(flag) if raise_if_missing && value.empty?
          block.call value
        end
      end
    end

    private def args_size
      @double_dash_index || @args.size
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

    private def check_invalid_options
      @args.each_with_index do |arg, index|
        return if (double_dash_index = @double_dash_index) && index >= double_dash_index

        if arg.starts_with?('-') && arg != "-"
          @parser.invalid_option.call(arg)
        end
      end
    end
  end
end
