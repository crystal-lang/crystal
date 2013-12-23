# Copied with little modifications from: https://github.com/acangiano/ruby-benchmark-suite/blob/master/benchmarks/macro-benchmarks/bm_sudoku.rb

def valid?(state, x, y)
  # check in col and row
  0.upto(state.size - 1) do |i|
    return false if i != y && state[x][i] == state[x][y]
    return false if i != x && state[i][y] == state[x][y]
  end

  # check in box
  x_from = (x / 3) * 3
  y_from = (y / 3) * 3
  x_from.upto(x_from + 2) do |xx|
    y_from.upto(y_from + 2) do |yy|
      return false if (xx != x || yy != y) && state[xx][yy] == state[x][y]
    end
  end

  true
end


def next_state(state, x, y)
  if y == state.size
    y = 0
    x = x + 1
  end
  return true if x == state.size

  unless state[x][y] == 0
    return false unless valid?(state, x, y)
    return next_state(state, x, y + 1)
  else
    1.upto(state.size) do |i|
    state[x][y] = i
      return true if valid?(state, x, y) && next_state(state, x, y + 1)
    end
  end

  state[x][y] = 0
  false
end

start =
    [
      [ 0, 0, 0, 4, 0, 5, 0, 0, 1 ],
      [ 0, 7, 0, 0, 0, 0, 0, 3, 0 ],
      [ 0, 0, 4, 0, 0, 0, 9, 0, 0 ],
      [ 0, 0, 3, 5, 0, 4, 1, 0, 0 ],
      [ 0, 0, 7, 0, 0, 0, 4, 0, 0 ],
      [ 0, 0, 8, 9, 0, 1, 0, 0, 0 ],
      [ 0, 0, 9, 0, 0, 0, 6, 0, 0 ],
      [ 0, 8, 0, 0, 0, 0, 0, 2, 0 ],
      [ 4, 0, 0, 2, 0, 0, 0, 0, 0 ]
    ]
next_state(start, 0, 0)

p start
