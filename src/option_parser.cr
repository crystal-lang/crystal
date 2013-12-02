class OptionParser
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

  def self.parse(args)
    parser = OptionParser.new(args)
    yield parser
    parser.check_invalid_options
    parser
  end

  def self.parse!
    parse(ARGV) { |parser| yield parser }
  end

  def initialize(@args)
    @flags = [] of String
  end

  def banner=(@banner)
  end

  def on(flag, description)
    append_flag flag.to_s, description
    parse_flag(flag) { |value| yield value }
  end

  def on(short_flag, long_flag, description)
    append_flag "#{short_flag}, #{long_flag}", description
    parse_flag(short_flag) { |value| yield value }
    parse_flag(long_flag) { |value| yield value }
  end

  def to_s
    String.build do |str|
      if @banner
        str << @banner
        str << "\n"
      end
      @flags.each_with_index do |flag, i|
        str << "\n" if i > 0
        str << flag
      end
    end
  end

  # private

  def append_flag(flag, description)
    @flags << String.build do |str|
      str << "    "
      str << flag
      (33 - flag.length).times do
        str << " "
      end
      str << description
    end
  end

  def parse_flag(flag)
    case flag
    when /--(\S+)\s+\[\S+\]/
      value = flag_value("--#{$1}")
      yield value if value
    when /--(\S+)\s+\S+/, /--(\S+)\s+/
      value = flag_value("--#{$1}", true)
      yield value if value
    when /--\S+/
      flag_present?(flag) && yield ""
    when /-(.)\s+\[\S+\]/
      value = flag_value(flag[0 .. 1])
      yield value if value
    when /-(.)\s+\S+/, /-(.)\s+/
      value = flag_value(flag[0 .. 1], true)
      yield value if value
    when /-(.)\[\S+\]/
      value = inline_flag_value(flag[0 ..1])
      yield value if value
    when /-(.)\S+/
      value = inline_flag_value(flag[0 .. 1], true)
      yield value if value
    else
      flag_present?(flag) && yield ""
    end
  end

  def flag_present?(flag)
    index = @args.index(flag)
    if index
      @args.delete_at(index)
      true
    else
      false
    end
  end

  def flag_value(flag, raise_if_missing = false)
    index = @args.index(flag)
    if index
      begin
        @args.delete_at(index)
        @args.delete_at(index)
      rescue IndexOutOfBounds
        raise MissingOption.new(flag) if raise_if_missing
        ""
      end
    else
      nil
    end
  end

  def inline_flag_value(flag, raise_if_missing = false)
    index = @args.index { |arg| arg.starts_with?(flag) }
    if index
      value = @args.delete_at(index)[2 .. -1]
      raise MissingOption.new(flag) if raise_if_missing && value.empty?
      value
    else
      nil
    end
  end

  def check_invalid_options
    @args.each do |arg|
      if arg.starts_with?('-')
        raise InvalidOption.new(arg)
      end
    end
  end
end
