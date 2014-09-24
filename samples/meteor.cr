# Translated from: https://github.com/mozilla/rust/blob/master/src/test/bench/shootout-meteor.rs

alias Masks = Array(Array(Array(UInt64)))
alias Point = Tuple(Int32, Int32)

class Iterator(T)
  include Enumerable

  def initialize(@data : T, &@block : T -> T)
  end

  def each
    while true
      yield @data
      @data = @block.call(@data)
    end
  end
end

def bo(offset) # bit offset
  1_u64 << offset
end

def bm(mask, offset) # bit mask
  mask & bo(offset)
end

def transform(piece, all)
  i = Iterator.new piece, &.map{ |yx| {yx[1] + yx[0], -yx[0]} }
  rots = i.take(all ? 6 : 3)
  res = rots.flat_map do |cur_piece|
    i2 = Iterator.new cur_piece, &.map { |yx| {yx[1], yx[0]} }
    i2.take(2)
  end

  res.map do |cur_piece|
    dy, dx = cur_piece.min
    cur_piece.map do |yx|
      {yx[0] - dy, yx[1] - dx}
    end
  end
end

def mask(dy, dx, id, p)
  m = bo(50 + id)
  p.each do |p1|
    y, x = p1
    x2 = x + dx + (y + (dy % 2)) / 2
    return if x2 < 0 || x2 > 4
    y2 = y + dy
    return if y2 < 0 || y2 > 9
    m |= bo(y2 * 5 + x2)
  end
  m
end

PIECES = [
    [{0,0},{0,1},{0,2},{0,3},{1,3}],
    [{0,0},{0,2},{0,3},{1,0},{1,1}],
    [{0,0},{0,1},{0,2},{1,2},{2,1}],
    [{0,0},{0,1},{0,2},{1,1},{2,1}],
    [{0,0},{0,2},{1,0},{1,1},{2,1}],
    [{0,0},{0,1},{0,2},{1,1},{1,2}],
    [{0,0},{0,1},{1,1},{1,2},{2,1}],
    [{0,0},{0,1},{0,2},{1,0},{1,2}],
    [{0,0},{0,1},{0,2},{1,2},{1,3}],
    [{0,0},{0,1},{0,2},{0,3},{1,2}]
]

def make_masks
  res = Masks.new
  PIECES.each_with_index do |p, id|
    trans = transform(p, id != 3)
    cur_piece = [] of Array(UInt64)
    10.times do |dy|
      5.times do |dx|
        cur_piece << trans.compact_map { |t| mask(dy, dx, id, t) }
      end
    end
    res << cur_piece
  end
  res
end

def is_board_unfeasible(board : UInt64, masks : Masks)
  coverable = board

  (0...50).select { |i| bm(board, i) == 0 }.each do |i|
    masks.each_with_index do |pos_masks, cur_id|
      next if bm(board, 50 + cur_id) != 0
      pos_masks[i].each do |cur_m|
        coverable |= cur_m if cur_m & board == 0
      end
    end
    return true if bm(coverable, i) == 0
  end

  coverable != (bo(60) - 1)
end

def filter_masks(masks : Masks)
  masks.map do |p|
    p.map do |p2|
      p2.select do |m|
        !is_board_unfeasible(m, masks)
      end
    end
  end
end

def get_id(m : UInt64)
  10.times do |id|
    return id.to_u8 if bm(m, id + 50) != 0
  end
  raise "does not have a valid identifier"
end

def to_utf8(raw_sol)
  String.new(50) do |buf|
    raw_sol.each do |m|
      id = get_id(m)
      50.times do |i|
        buf[i] = '0'.ord.to_u8 + id if bm(m, i) != 0
      end
    end
    {50, 50}
  end
end

def print_sol(str)
  i = 0
  str.each_byte do |c|
    puts if i % 5 == 0
    print " " if (i + 5) % 10 == 0
    print " "
    print c.chr
    i += 1
  end
  puts
end

class SolutionNode
  def initialize(@x, @prev)
  end
  getter :x
  getter :prev

  def each
    yield @x
    p = prev
    while y = p
      yield y.x
      p = p.prev
    end
  end
end

class Meteor
  def initialize(@masks : Masks, @stop_after)
    @nb = 0
    @min = "9" * 50
    @max = "0" * 50
  end
  property :min
  property :max
  property :nb

  def handle_sol(cur)
    @nb += 2
    sol1 = to_utf8(cur)
    sol2 = sol1.reverse
    @min = {sol1, sol2, @min}.min
    @max = {sol1, sol2, @max}.max
    nb < @stop_after
  end

  def search(board, i, cur = nil)
    while bm(board, i) != 0 && (i < 50)
      i += 1
    end

    return handle_sol(cur) if i >= 50 && cur

    (0...10).each do |id|
      if bm(board, id + 50) == 0
        @masks[id][i].each do |m|
          if board & m == 0
            return false if !search(board | m, i + 1, SolutionNode.new(m, cur))
          end
        end
      end
    end

    true
  end
end

stop_after = (ARGV[0]? || 2098).to_i
masks = filter_masks(make_masks)
data = Meteor.new(masks, stop_after)
data.search(0_u64, 0)
puts "#{data.nb} solutions found"
print_sol(data.min)
print_sol(data.max)
puts


