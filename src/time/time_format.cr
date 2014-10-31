struct TimeFormat
  getter pattern

  def initialize(@pattern : String)
  end

  def parse(string)
    # TimeParser.new(pattern, string).parse
  end

  def format(time : Time)
    String.build do |str|
      format time, str
    end
  end

  def format(time : Time, io : IO)
    formatter = Formatter.new(time, io)
    formatter.visit(pattern)
  end
end
