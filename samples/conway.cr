# Ported from http://arthurtw.github.io/2015/01/12/quick-comparison-nim-vs-rust.html

struct ANSI
  def initialize(@io : IO)
  end

  def clear
    @io << "\e[2J"
  end

  def pos(x, y)
    @io << "\e[" << x << ';' << y << 'H'
  end
end

class IO
  def ansi
    ANSI.new self
  end
end

struct ConwayMap
  WIDTH  = 40
  HEIGHT = 30

  include Math

  @map : Array(Array(Bool))

  def initialize(pattern)
    @map = Array.new(HEIGHT) { Array.new(WIDTH, false) }

    ix = min WIDTH, pattern.map(&.size).max
    iy = min HEIGHT, pattern.size
    dx = (WIDTH - ix) / 2
    dy = (HEIGHT - iy) / 2

    iy.times do |y|
      ix.times do |x|
        if x < pattern[y].size && !pattern[y][x].whitespace?
          @map[y + dy][x + dx] = true
        end
      end
    end
  end

  def next
    old_map = @map.clone

    HEIGHT.times do |i|
      WIDTH.times do |j|
        nlive = 0

        max(i - 1, 0).upto(min(i + 1, HEIGHT - 1)) do |i2|
          max(j - 1, 0).upto(min(j + 1, WIDTH - 1)) do |j2|
            nlive += 1 if old_map[i2][j2] && (i2 != i || j2 != j)
          end
        end

        if @map[i][j]
          @map[i][j] = 2 <= nlive <= 3
        else
          @map[i][j] = nlive == 3
        end
      end
    end
  end

  def to_s(io)
    io.ansi.clear
    io.ansi.pos 1, 1
    @map.each do |row|
      row.each do |cell|
        io << (cell ? "()" : ". ")
      end
      io.puts
    end
  end
end

PAUSE_MILLIS  =  20
DEFAULT_COUNT = 300
INITIAL_MAP   = [
  "                        1           ",
  "                      1 1           ",
  "            11      11            11",
  "           1   1    11            11",
  "11        1     1   11              ",
  "11        1   1 11    1 1           ",
  "          1     1       1           ",
  "           1   1                    ",
  "            11                      ",
]

map = ConwayMap.new INITIAL_MAP

spawn { gets; exit }

1.upto(DEFAULT_COUNT) do |i|
  puts map
  puts "n = #{i}\tPress ENTER to exit"
  sleep PAUSE_MILLIS * 0.001
  map.next
end
