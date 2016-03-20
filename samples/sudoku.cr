# Copied with little modifications from: https://github.com/attractivechaos/plb/blob/master/sudoku/sudoku_v1.rb

def sd_genmat
  mr = Array.new(324) { [] of Int32 }
  mc = Array.new(729) { [] of Int32 }
  r = 0
  (0...9).each do |i|
    (0...9).each do |j|
      (0...9).each do |k|
        mc[r] = [9 * i + j, (i / 3 * 3 + j / 3) * 9 + k + 81, 9 * i + k + 162, 9 * j + k + 243]
        r += 1
      end
    end
  end
  (0...729).each do |r2|
    (0...4).each do |c2|
      mr[mc[r2][c2]].push(r2)
    end
  end
  {mr, mc}
end

def sd_update(mr, mc, sr, sc, r, v)
  min, min_c = 10, 0
  (0...4).each do |c2|
    if v > 0
      sc[mc[r][c2]] += 128
    else
      sc[mc[r][c2]] -= 128
    end
  end
  (0...4).each do |c2|
    c = mc[r][c2]
    if v > 0
      (0...9).each do |r2|
        rr = mr[c][r2]
        sr[rr] += +1
        if sr[rr] == 1
          p = mc[rr]
          sc[p[0]] -= 1; sc[p[1]] -= 1; sc[p[2]] -= 1; sc[p[3]] -= 1
          if sc[p[0]] < min
            min, min_c = sc[p[0]], p[0]
          end
          if sc[p[1]] < min
            min, min_c = sc[p[1]], p[1]
          end
          if sc[p[2]] < min
            min, min_c = sc[p[2]], p[2]
          end
          if sc[p[3]] < min
            min, min_c = sc[p[3]], p[3]
          end
        end
      end
    else
      (0...9).each do |r2|
        rr = mr[c][r2]
        sr[rr] -= 1
        if sr[rr] == 0
          p = mc[rr]
          sc[p[0]] += 1; sc[p[1]] += 1; sc[p[2]] += 1; sc[p[3]] += 1
        end
      end
    end
  end
  {min, min_c}
end

def sd_solve(mr, mc, s)
  ret = [] of Array(Int32)
  sr, sc, hints = Array.new(729, 0), Array.new(324, 9), 0
  (0...81).each do |i|
    a = ('1' <= s[i] <= '9') ? s[i].ord - 49 : -1
    if a >= 0
      sd_update(mr, mc, sr, sc, i * 9 + a, 1)
      hints += 1
    end
  end
  cr, cc = Array.new(81, -1), Array.new(81, 0)
  i, min, dir = 0, 10, 1
  loop do
    while i >= 0 && i < 81 - hints
      if dir == 1
        if min > 1
          (0...324).each do |c|
            if sc[c] < min
              min, cc[i] = sc[c], c
              break if min < 2
            end
          end
        end
        if min == 0 || min == 10
          cr[i], dir, i = -1, -1, i - 1
        end
      end
      c = cc[i]
      if dir == -1 && cr[i] >= 0
        sd_update(mr, mc, sr, sc, mr[c][cr[i]], -1)
      end
      r2_ = 9
      (cr[i] + 1...9).each do |r2|
        if sr[mr[c][r2]] == 0
          r2_ = r2
          break
        end
      end
      if r2_ < 9
        min, cc[i + 1] = sd_update(mr, mc, sr, sc, mr[c][r2_], 1)
        cr[i], dir, i = r2_, 1, i + 1
      else
        cr[i], dir, i = -1, -1, i - 1
      end
    end
    break if i < 0
    o = [] of Int32
    (0...81).each { |j| o.push((s[j].ord - 49).to_i32) }
    (0...i).each do |j|
      r = mr[cc[j]][cr[j]]
      o[r / 9] = r % 9 + 1
    end
    ret.push(o)
    i, dir = i - 1, -1
  end
  ret
end

sudoku = "
..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9       near worst case for brute-force solver (wiki)
.......12........3..23..4....18....5.6..7.8.......9.....85.....9...4.5..47...6...       gsf's sudoku q1 (Platinum Blonde)
.2..5.7..4..1....68....3...2....8..3.4..2.5.....6...1...2.9.....9......57.4...9..       (Cheese)
........3..1..56...9..4..7......9.5.7.......8.5.4.2....8..2..9...35..1..6........       (Fata Morgana)
12.3....435....1....4........54..2..6...7.........8.9...31..5.......9.7.....6...8       (Red Dwarf)
1.......2.9.4...5...6...7...5.9.3.......7.......85..4.7.....6...3...9.8...2.....1       (Easter Monster)
.......39.....1..5..3.5.8....8.9...6.7...2...1..4.......9.8..5..2....6..4..7.....       Nicolas Juillerat's Sudoku explainer 1.2.1 (top 5)
12.3.....4.....3....3.5......42..5......8...9.6...5.7...15..2......9..6......7..8
..3..6.8....1..2......7...4..9..8.6..3..4...1.7.2.....3....5.....5...6..98.....5.
1.......9..67...2..8....4......75.3...5..2....6.3......9....8..6...4...1..25...6.
..9...4...7.3...2.8...6...71..8....6....1..7.....56...3....5..1.4.....9...2...7..
....9..5..1.....3...23..7....45...7.8.....2.......64...9..1.....8..6......54....7       dukuso's suexrat9 (top 1)
7.8...3.....2.1...5.........4.....263...8.......1...9..9.6....4....7.5...........
3.7.4...........918........4.....7.....16.......25..........38..9....5...2.6.....
........8..3...4...9..2..6.....79.......612...6.5.2.7...8...5...1.....2.4.5.....3       dukuso's suexratt (top 1)
.......1.4.........2...........5.4.7..8...3....1.9....3..4..2...5.1........8.6...       first 2 from sudoku17
.......12....35......6...7.7.....3.....4..8..1...........12.....8.....4..5....6..
1.......2.9.4...5...6...7...5.3.4.......6........58.4...2...6...3...9.8.7.......1       2 from http://www.setbb.com/phpbb/viewtopic.php?p=10478
.....1.2.3...4.5.....6....7..2.....1.8..9..3.4.....8..5....2....9..3.4....67.....
"

def solve_all(sudoku)
  mr, mc = sd_genmat()
  sudoku.split("\n").map do |line|
    if line.size >= 81
      ret = sd_solve(mr, mc, line)
      ret.map { |s2| s2.join }
    end
  end.compact
end

10.times do |i|
  res = solve_all(sudoku)
  res.each { |str| puts str } if i == 0
end
