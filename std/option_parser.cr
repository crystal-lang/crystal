class OptionParser
  class MissingArgument < Exception
    def initialize(argument)
      super("Missing argument: #{argument}")
    end
  end

  def self.parse(args)
    parser = OptionParser.new(args)
    yield parser
    parser
  end

  def self.parse!
    parser = OptionParser.new(ARGV)
    yield parser
    parser
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
      yield flag_value("--#{$1}", false)
    when /--(\S+)\s+\S+/
      yield flag_value("--#{$1}")
    when /--\S+/
      flag_present?(flag) && yield true
    when /-(.)\s+\S+/
      yield flag_value(flag[0 .. 1])
    when /-(.)\s+/
      yield flag_value(flag[0 .. 1], false)
    when /-(.)\[\S+\]/
      yield inline_flag_value(flag[0 ..1], false)
    when /-(.)[A-Z]+/
      yield inline_flag_value(flag[0 .. 1])
    else
      flag_present?(flag) && yield true
    end
  end

  def flag_present?(flag)
    index = @args.index(flag)
    if index != -1
      @args.delete_at(index)
      true
    else
      false
    end
  end

  def flag_value(flag, raise_if_not_found = true)
    index = @args.index(flag)
    if index != -1
      begin
        @args.delete_at(index)
        @args.delete_at(index)
      rescue Array::IndexOutOfBounds
        raise MissingArgument.new(flag)
      end
    else
      raise MissingArgument.new(flag) if raise_if_not_found
    end
  end

  def inline_flag_value(flag, raise_if_not_found = true)
    index = @args.index { |arg| arg.starts_with?(flag) }
    if index != -1
      @args.delete_at(index)[2 .. -1]
    else
      raise MissingArgument.new(flag) if raise_if_not_found
    end
  end
end
