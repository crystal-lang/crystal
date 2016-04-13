# Brainf*ck interpreter

struct Tape
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
    raise "pos should be > 0" if @pos < 0
  end
end

class Program
  def initialize(@chars : Array(Char), @bracket_map : Hash(Int32, Int32))
  end

  def run
    tape = Tape.new
    pc = 0
    while pc < @chars.size
      case @chars[pc]
      when '>'; tape.advance
      when '<'; tape.devance
      when '+'; tape.inc
      when '-'; tape.dec
      when '.'; print tape.get.chr
      when '['; pc = @bracket_map[pc] if tape.get == 0
      when ']'; pc = @bracket_map[pc] if tape.get != 0
      end
      pc += 1
    end
  end

  def self.parse(text)
    parsed = [] of Char
    bracket_map = {} of Int32 => Int32
    leftstack = [] of Int32
    pc = 0
    text.each_char do |char|
      if "[]<>+-,.".includes?(char)
        parsed << char
        if char == '['
          leftstack << pc
        elsif char == ']' && !leftstack.empty?
          left = leftstack.pop
          right = pc
          bracket_map[left] = right
          bracket_map[right] = left
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
         <<-PROGRAM
         Benchmark brainf*ck program
         >++[<+++++++++++++>-]<[[>+>+<<-]>[<+>-]++++++++
         [>++++++++<-]>.[-]<<>++++++++++[>++++++++++[>++
         ++++++++[>++++++++++[>++++++++++[>++++++++++[>+
         +++++++++[-]<-]<-]<-]<-]<-]<-]<-]++++++++++.
         PROGRAM
       end

Program.parse(text).run
