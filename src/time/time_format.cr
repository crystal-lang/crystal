struct TimeFormat
  class Error < ::Exception
  end

  getter pattern

  def initialize(@pattern : String)
  end

  def parse(string)
    parser = Parser.new(string)
    parser.visit(pattern)
    parser.time
  end

  def format(time : Time)
    String.build do |str|
      format time, str
    end
  end

  def format(time : Time, io : IO)
    formatter = Formatter.new(time, io)
    formatter.visit(pattern)
    io
  end
end
