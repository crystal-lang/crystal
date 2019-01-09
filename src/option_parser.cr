require "bit_array"

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
#   parser.invalid_option do |flag|
#     STDERR.puts "ERROR: #{flag} is not a valid option."
#     STDERR.puts parser
#     exit(1)
#   end
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
  # and uses it to parse the passed *args*. Options are removed from *args* if *consume_args* is `true`.
  def self.parse(args, consume_args = true) : self
    parser = OptionParser.new
    yield parser
    parser.parse(args, consume_args)
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

    if short_flag.size <= 2 && long_flag =~ /([ =].+)/
      short_flag += $1.lchop('=')
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
  def to_s(io : IO) : Nil
    if banner = @banner
      io << banner
      io << '\n'
    end
    @flags.join '\n', io
  end

  private def append_flag(flag, description)
    if flag.size >= 33
      @flags << "    #{flag}\n#{" " * 37}#{description}"
    else
      @flags << "    #{flag}#{" " * (33 - flag.size)}#{description}"
    end
  end

  # Parses the passed *args*, running the handlers associated to each option.
  def parse(args, consume_args = true)
    ParseTask.new(self, args, consume_args).parse
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
    @dash_args_size : Int32

    def initialize(@parser : OptionParser, @args : Array(String), @consume_args : Bool)
      dash_args_size = @dash_args_size = @args.index("--") || @args.size
      consumable_max = 0
      if dash_args_size > 0
        if last_flag_index = @args.rindex(offset: dash_args_size - 1) { |arg| arg_is_flag?(arg) }
          consumable_max = Math.min(dash_args_size, last_flag_index + 2) # +2 for value after last flag
        end
      end
      @consumable_args = BitArray.new(consumable_max)
    end

    def parse
      @parser.handlers.each do |handler|
        process_handler handler
      end
      check_invalid_options

      consumed = @consumable_args.count(true)
      consumed_max = @consumable_args.size
      dash_args = @dash_args_size

      if @consume_args
        index = 0
        @args.reject! do |arg|
          reject = index < consumed_max ? @consumable_args[index] : (index == dash_args)
          index += 1
          reject
        end
        dash_args -= consumed
        consumed_max = consumed = 0
      end

      if unknown_args = @parser.unknown_args
        if consumed == 0 && dash_args == @args.size
          before_dash = @args # dup?
        else
          before_dash = Array(String).new(dash_args - consumed)
          each_consumable_arg { |arg| before_dash << arg } unless consumed == consumed_max
          consumed_max.upto(dash_args - 1) { |index| before_dash << @args[index] }
        end

        after_dash = @args.skip(@consume_args ? dash_args : dash_args + 1) # +1 skip double dash (--) argument
        unknown_args.call(before_dash, after_dash)
      end
    end

    private def process_handler(handler)
      flag = handler.flag
      block = handler.block
      case flag
      when /\A(--\S+)(\s+|=)\[\S+\]\z/
        process_double_flag($1, block, true, $2 != "=")
      when /\A(--\S+)(?:\s+|=)(?:\S+)?\z/
        process_double_flag($1, block)
      when /\A--\S+\z/
        process_flag_presence(flag, block)
      when /\A(-.)(\s*)\[\S+\]\z/
        process_single_flag($1, block, true, $2 != "")
      when /\A(-.)\s*\S+\z/, /\A(-.)\s+\z/
        process_single_flag($1, block)
      else
        process_flag_presence(flag, block)
      end
    end

    private def process_flag_presence(flag, block)
      each_consumable_arg do |arg, index|
        next unless arg == flag
        consume_arg_at_index(index)
        block.call ""
      end
    end

    private def process_double_flag(flag, block, optional = false, separate = true)
      each_consumable_arg do |arg, index|
        next unless arg.starts_with?(flag)
        arg = consume_arg_at_index(index)
        if arg.size == flag.size
          value = consume_value_at_index(index + 1, optional, separate)
        elsif arg[flag.size] == '='
          value = arg[flag.size + 1..-1]
        else
          unconsume_arg_at_index(index)
          next
        end
        @parser.missing_option.call(flag) if !optional && value.empty?
        block.call value
      end
    end

    private def process_single_flag(flag, block, optional = false, separate = true)
      each_consumable_arg do |arg, index|
        next unless arg.starts_with?(flag)
        arg = consume_arg_at_index(index)
        value = arg.size == flag.size ? consume_value_at_index(index + 1, optional, separate) : arg[2..-1]
        @parser.missing_option.call(flag) if !optional && value.empty?
        block.call value
      end
    end

    private def each_consumable_arg
      @consumable_args.each_with_index do |consumed, index|
        yield @args[index], index unless consumed
      end
    end

    private def consume_value_at_index(index, optional, separate)
      if separate && @consumable_args[index]? == false
        return consume_arg_at_index(index) unless optional && arg_is_flag?(@args[index])
      end
      ""
    end

    private def consume_arg_at_index(index)
      @consumable_args[index] = true
      @args[index]
    end

    private def unconsume_arg_at_index(index)
      @consumable_args[index] = false
    end

    private def arg_is_flag?(arg)
      arg.starts_with?('-') && arg != "-"
    end

    private def check_invalid_options
      each_consumable_arg do |arg|
        @parser.invalid_option.call(arg) if arg_is_flag?(arg)
      end
    end
  end
end
