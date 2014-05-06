# Based on 2048 by Gabriele Cirulli - gabrielecirulli.github.io/2048

require "io/console"

module Screen
  COLORS = {
    :black => 0,
    :red => 1,
    :green => 2,
    :yellow => 3,
    :blue => 4,
    :pink => 5,
    :cyan => 6,
    :white => 7
  }

  TILES = {
        0 => {:white, :black},
        2 => {:black, :white},
        4 => {:blue,  :white},
        8 => {:black, :yellow},
       16 => {:white, :red},
       32 => {:black, :red},
       64 => {:white, :pink},
      128 => {:red,   :yellow},
      256 => {:pink,  :yellow},
      512 => {:white, :yellow},
     1024 => {:white, :yellow},
     2048 => {:white, :yellow},
     4096 => {:white, :black},
     8192 => {:white, :black},
    16384 => {:white, :black},
    32768 => {:white, :black},
    65536 => {:white, :black}
  }

  def self.set_for tile
    fg_color, bg_color = TILES[tile]
    set_fg fg_color
    set_bg bg_color
  end

   def self.set_fg fg_color
     print  "\x1b[#{COLORS[fg_color]+30}m"
   end

   def self.set_bg bg_color
     print  "\x1b[;#{COLORS[bg_color]+40}m"
   end

   def self.reset
     print  "\x1b[0m"
   end

  def self.clear
    print "\x1b[2J\x1b[1;1H"
  end

  def self.read_keypress
    STDIN.raw do |io|
      input = io.read 1
      if input == "\e"
        remaining = io.read_nonblock 3
        remaining = io.read_nonblock 2 unless remaining
        input = input+remaining if remaining
      end

      case input
      when "\x1B[A"
        :up
      when "\x1B[B"
        :down
      when "\x1B[C"
        :right
      when "\x1B[D"
        :left
      when "\x1B"
        :escape
      when "\x03"
        :ctrl_c
      when "q"
        :q
      when "Q"
        :q
      else
        :unknown
      end
    end
  end
end

class Drawer
  INNER_CELL_WIDTH = 16
  INNER_CELL_HEIGHT = 6

  def initialize
    @n = 0
    @grid = [] of Array(String)
    @current_row = [] of String
    @content_line = false
  end

  def set_current_row row
    @current_row = row
  end

  def draw grid
    @grid = grid
    @n = @grid.size

    Screen.clear
    box
  end

  def box
    top_border

    (@n-1).times do |row|
      tile row
      mid_border
    end

    tile @n-1

    bottom_border
  end

  def tile row
    set_current_row @grid[row]

    INNER_CELL_HEIGHT.times do |i|
      if i == (@n / 2)+1
        content_line
      else
        space_line
      end
    end

    set_current_row [] of String
  end

  def space_line
    line "│", " ", "│", "│"
  end

  def content_line
    @content_line = true
    space_line
    @content_line = false
  end

  def top_border
    line "┌", "─", "┬", "┐"
  end

  def mid_border
    line "├", "─", "┼", "┤"
  end

  def bottom_border
    line "└", "─", "┴", "┘"
  end

  def line left, fill, inner, right
    print left

    (@n-1).times do |cell|
      cell_line fill, cell

      print inner
    end

    cell_line fill, @n-1

    puts right
  end

  def cell_line fill, cell
    content = @current_row.at(cell) { "empty" }
    tile_value = (content == "empty" ? 0 : content).to_i
    content = "" if !@content_line || content == "empty"

    fill_size = INNER_CELL_WIDTH / 2
    fill_size -= content.length / 2
    fill_size -= 2

    print fill
    Screen.set_for tile_value
    print fill*fill_size
    print content
    print fill*fill_size
    print fill if content.length % 2 == 0
    Screen.reset
    print fill
  end
end

class Game
  def initialize
    @drawer = Drawer.new
    @grid = [
      [:empty, :empty, :empty, :empty] of Int32|Symbol,
      [:empty, :empty, :empty, :empty] of Int32|Symbol,
      [:empty, :empty, :empty, :empty] of Int32|Symbol,
      [:empty, :empty, :empty, :empty] of Int32|Symbol
    ]

    insert_tile
    insert_tile
  end

  def run
    draw

    while !won? && !lost?
    #until won? || lost? # would be nicer here
      insert_tile if execute_action read_action
      draw
    end

    if won?
      end_game "You won!"
    elsif lost?
      end_game "You lost!"
    else
      raise "Game loop quitted unexpectedly"
    end
  end

  def draw
    @drawer.draw drawable_grid
  end

  def drawable_grid
    @grid.map &.map(&.to_s)
  end

  def read_action
    Screen.read_keypress
  end

  def insert_tile
    value = rand > 0.8 ? 4 : 2

    empty_cells = @grid.map(&.count(:empty)).sum

    fill_cell = empty_cells > 1 ? rand(empty_cells-1)+1 : 1

    empty_cell_count = 0

    each_cell_with_index do |tile, row, col|
      empty_cell_count += 1 if tile == :empty

      if empty_cell_count == fill_cell
        @grid[row][col] = value
        return
      end
    end
  end

  def each_cell_with_index
    0.upto(@grid.size-1) do |row|
      0.upto(@grid.size-1) do |col|
        yield @grid[row][col], row, col
      end
    end
  end

  def execute_action action
    if [:up, :down, :left, :right].includes? action
      if can_move_in? action
        shift_grid action
        true
      else
        false
      end
    elsif [:ctrl_c, :escape, :q].includes? action
      end_game "Bye"
    elsif action == :unknown
      false # ignore
    else
      raise ArgumentError.new "Unknown action: #{action}"
    end
  end

  def shift_grid direction
    drow, dcol = offsets_for direction
    shift_tiles_to_empty_cells direction, drow, dcol
    merge_tiles direction, drow, dcol
    shift_tiles_to_empty_cells direction, drow, dcol
  end

  def shift_tiles_to_empty_cells direction, drow, dcol
    modified = true
    while modified
      modified = false
      movable_tiles(direction, drow, dcol) do |tile, row, col|
        if @grid[row+drow][col+dcol] == :empty
          @grid[row+drow][col+dcol] = tile
          @grid[row][col] = :empty
          modified = true
        end
      end
    end
  end

  def merge_tiles direction, drow, dcol
    movable_tiles(direction, drow, dcol) do |tile, row, col|
      if @grid[row+drow][col+dcol] == tile
        @grid[row][col] = :empty
         # crystal doesn't see the next in movable_tiles or doesn't know that :empty is
         # only Symbol value, so we need to guard here. However the condition is always true
        @grid[row+drow][col+dcol] = tile*2 if tile.is_a? Int
      end
    end
  end

  # This method could be cleaned up with some way to iterate
  # from, for example,  x = 0 to y = 20 and from x = 20 to y = 0
  # with the same x.to(y) do |i| call
  def movable_tiles direction, drow, dcol
    macro movable_tiles_action rows, cols
      "
      #{rows} do |row|
        #{cols} do |col|
          tile = @grid[row][col]
          next if tile == :empty || to_border?(direction, row, col, drow, dcol)

          yield tile, row, col
        end
      end
      "
    end

    case direction
    when :up
      movable_tiles_action "0.upto(@grid.size-1)", "0.upto(@grid.size-1)"
    when :down
      movable_tiles_action "(@grid.size-1).downto(0)", "0.upto(@grid.size-1)"
    when :left
      movable_tiles_action "0.upto(@grid.size-1)", "0.upto(@grid.size-1)"
    when :right
      movable_tiles_action "0.upto(@grid.size-1)", "(@grid.size-1).downto(0)"
    else
      raise ArgumentError.new "Unknown direction #{direction}"
       # Makes the parser happy, through the macro it doesn't realize that the method
       # takes a block
      yield 0, 0, 0
    end
  end

  def can_move_in? direction
    drow, dcol = offsets_for direction

    movable_tiles(direction, drow, dcol) do |tile, row, col|
      return true if @grid[row+drow][col+dcol] == tile ||
                     @grid[row+drow][col+dcol] == :empty
    end

    false
  end

  def offsets_for direction
    drow = dcol = 0

    case direction
    when :up
      drow = -1
    when :down
      drow = 1
    when :left
      dcol = -1
    when :right
      dcol = 1
    else
      raise ArgumentError.new "Unknown direction #{direction}"
    end

    {drow, dcol}
  end

  def to_border? direction, row, col, drow, dcol
    case direction
    when :up
      row+drow < 0
    when :down
      row+drow >= @grid.size
    when :left
      col+dcol < 0
    when :right
      col+dcol >= @grid.size
    else
      false
    end
  end

  def won?
    @grid.any? &.any?(&.==(2048))
  end

  def lost?
    !can_move?
  end

  def can_move?
    can_move_in?(:up) || can_move_in?(:down) ||
    can_move_in?(:left) || can_move_in?(:right)
  end

  def end_game msg
    puts msg
    exit
  end
end

Game.new.run
