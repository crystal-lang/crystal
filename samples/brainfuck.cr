# Brainf*ck interpreter

class Tape
  def initialize
    @tape = [0]
    @pos = 0
  end

  def get
    @tape[@pos]
  end

  def inc
    @tape[@pos] += 1
  end

  def dec
    @tape[@pos] -= 1
  end

  def advance
    @pos += 1
    @tape << 0 if @tape.size <= @pos
  end

  def devance
    @pos -= 1
  end
end

class Program
  def initialize(text, bracket_map)
    @text = text
    @bracket_map = bracket_map
    @tape = Tape.new
    @pc = 0
  end

  def step(code)
    case code
      when '>'; @tape.advance
      when '<'; @tape.devance
      when '+'; @tape.inc
      when '-'; @tape.dec
      when '.'; print(@tape.get.chr)
      when '['; @pc = @bracket_map[@pc] if @tape.get == 0
      when ']'; @pc = @bracket_map[@pc] if @tape.get != 0
    end
  end

  def run
    while @pc < @text.length
      step(@text[@pc])
      @pc += 1
    end
  end

  def self.parse(text)
    parsed = ""
    bracket_map = {} of Int32 => Int32
    leftstack = [] of Int32
    pc = 0
    text.each_char do |char|
      if ['[', ']', '<', '>', '+', '-', ',', '.'].includes?(char)
        parsed += char.to_s
        if char == '['
          leftstack << pc
        elsif char == ']' && !leftstack.empty?
          left = leftstack.pop
          right = pc
          if left && right
            bracket_map[left] = right
            bracket_map[right] = left
          end
        end
        pc += 1
      end
    end

    Program.new(parsed, bracket_map)
  end
end

text = if ARGV.size > 0
  File.read(ARGV[0])
else
  ">++[<+++++++++++++>-]<[[>+>+<<-]>[<+>-]++++++++
[>++++++++<-]>.[-]<<>++++++++++[>++++++++++[>++
++++++++[>++++++++++[>++++++++++[>++++++++++[>+
+++++++++[-]<-]<-]<-]<-]<-]<-]<-]++++++++++.
  "
end

Program.parse(text).run

