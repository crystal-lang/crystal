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
#     require "option_parser"
#
#     upcase = false
#     destination = "World"
#
#     OptionParser.parse! do |parser|
#       parser.banner = "Usage: salute [arguments]"
#       parser.on("-u", "--upcase", "Upcases the sallute") { upcase = true }
#       parser.on("-t NAME", "--to=NAME", "Specifies the name to salute") { |name| destination = name }
#       parser.on("-h", "--help", "Show this help") { puts parser }
#     end
#
#     destination = destination.upcase if upcase
#     puts "Hello #{destination}!"
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
  record Handler, flag, block

  # Creates a new parser, with its configuration specified in the block, and uses it to parse the passed `args`.
  def self.parse(args)
    parser = OptionParser.new
    yield parser
    parser.parse(args)
    parser
  end

  # Creates a new parser, with its configuration specified in the block, and uses it to parse the arguments passed to the program.
  def self.parse!
    parse(ARGV) { |parser| yield parser }
  end

  # Creates a new parser.
  def initialize
    @flags = [] of String
    @handlers = [] of Handler
  end

  # Creates a new parser, with its configuration specified in the block.
  def self.new
    new.tap { |parser| yield parser }
  end

  # Establishes the initial message for the help printout. Typically, you want to write here the name of your program,
  # and a one-line template of its invocation.
  #
  # Example:
  #
  #     parser.banner = "Usage: crystal [command] [switches] [program file] [--] [arguments]"
  #
  setter banner

  # Establishes a handler for a flag.
  #
  # Flags can (but don't have to) start with a dash. They can also have an optional argument, which will get passed to
  # the block. Each flag has a description, which will be used for the help message.
  #
  # Examples of valid flags:
  #
  # * `-a`, `-B`
  # * `--something-longer`
  # * `-f FILE`, `--file FILE`, `--file=FILE`  (these will yield the passed value to the block as a string)
  def on(flag, description, &block : String ->)
    append_flag flag.to_s, description
    @handlers << Handler.new(flag, block)
  end

  # Establishes a handler for a pair of short and long flags.
  #
  # See the other definition of `on` for examples.
  def on(short_flag, long_flag, description, &block : String ->)
    append_flag "#{short_flag}, #{long_flag}", description
    @handlers << Handler.new(short_flag, block)
    @handlers << Handler.new(long_flag, block)
  end

  # Adds a separator, with an optional header message, that will be used to print the help.
  #
  # This way, you can group the different options in an easier to read way.
  def separator(message = "")
    @flags << message.to_s
  end

  # Sets a handler for arguments that didn't match any of the setup options.
  #
  # You typically use this to get the main arguments (not modifiers) that your program expects (for example, filenames)
  def unknown_args(&@unknown_args : Array(String), Array(String) ->)
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
    @flags << String.build do |str|
      str << "    "
      str << flag
      (33 - flag.size).times do
        str << " "
      end
      str << description
    end
  end

  # Parses the passed *args*, running the handlers associated to each option.
  def parse(args)
    ParseTask.new(args, @flags, @handlers, @unknown_args).parse
  end

  # Parses the passed the arguments passed to the program, running the handlers associated to each option.
  def parse!
    parse ARGV
  end

  # :nodoc:
  struct ParseTask
    def initialize(@args, @flags, @handlers, @unknown_args)
      double_dash_index = @double_dash_index = @args.index("--")
      if double_dash_index
        @args.delete_at(double_dash_index)
      end
    end

    def parse
      @handlers.each do |handler|
        process_handler handler
      end

      if unknown_args = @unknown_args
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
      while index = args_index { |arg| arg.starts_with?(flag) }
        arg = @args[index]
        if arg.size == flag.size
          delete_arg_at_index(index)
          if index < args_size
            block.call delete_arg_at_index(index)
          else
            if raise_if_missing
              raise MissingOption.new(flag)
            end
          end
        elsif arg[flag.size] == '='
          delete_arg_at_index(index)
          value = arg[flag.size + 1..-1]
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
        if arg.size == flag.size
          if index < args_size
            block.call delete_arg_at_index(index)
          else
            raise MissingOption.new(flag) if raise_if_missing
          end
        else
          value = arg[2..-1]
          raise MissingOption.new(flag) if raise_if_missing && value.empty?
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
          raise InvalidOption.new(arg)
        end
      end
    end
  end
end
